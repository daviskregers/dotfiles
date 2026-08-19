import type { HookResult, HookCtx, HookInput } from "./hook-utils"
import { execFile } from "node:child_process"
import { promisify } from "node:util"
import { readFileSync, writeFileSync, mkdirSync } from "node:fs"
import { homedir } from "node:os"
import { join, dirname } from "node:path"
import { createHash } from "node:crypto"

// Before a file write, report how much UNCOMMITTED churn has piled up, so a session hands
// back reviewable slices instead of one unreviewable diff. Advisory on both targets — it
// never blocks, because a denied edit invites the agent to route around it via shell.
// Churn is measured against HEAD (worktree + index), so committing resets it to zero with
// no state to clear. Dedup by diff signature keeps it to once per 100-line bucket per
// repo. Claude runs this before the edit lands, opencode after — a one-edit offset that
// doesn't matter at this granularity. FAIL-OPEN: any error → no nudge.

const exec = promisify(execFile)

// Churn (added + deleted, uncommitted) past which a diff stops being reviewable in one
// sitting. config.go reads this literal out of the source to keep global.md and start.md
// quoting the same number — renaming it breaks generation loudly.
export const MIN_LINES = 250

// Paths whose churn isn't review work: lockfiles, generated output, minified bundles,
// vendored trees. A DENYLIST rather than a source-extension allowlist, because the
// reviewable set is polyglot (shell scripts with no extension, markdown, .conf) and an
// allowlist silently scores those zero. Directory names are segment-anchored so a
// repo-root `node_modules/` matches as well as a nested one; `lock` is matched only in
// lockfile shape (`bun.lock`, `nvim-pack-lock.json`) so `blocklist.ts` still counts.
const IGNORE = /(^|\/)(node_modules|vendor|dist)\/|\.lock$|-lock\.|\.min\.|generated/i

// Parse one `git diff --numstat` block → the files touched + total churn.
export function parseNumstat(output: string): { files: string[]; lines: number } {
    let lines = 0
    const files: string[] = []
    for (const row of output.split("\n")) {
        const parts = row.split("\t")
        if (parts.length !== 3) continue
        const [added, deleted, path] = parts
        if (IGNORE.test(path)) continue
        files.push(path)
        lines += (/^\d+$/.test(added) ? +added : 0) + (/^\d+$/.test(deleted) ? +deleted : 0)
    }
    return { files, lines }
}

// Coarse signature: same file-set + churn bucket → same sig, so we re-nudge only on
// material growth (bucket of 100 lines), not on every tiny change.
export function signature(cwd: string, files: string[], lines: number): string {
    const bucket = Math.floor(lines / 100)
    const raw = cwd + "|" + [...files].sort().join("|") + `|${bucket}`
    return createHash("sha1").update(raw).digest("hex")
}

// Claude's file-writing tool names plus opencode's, merged — each target matches only
// its own and the rest are inert (same convention as ai-attribution's FIELD_MAP).
const EDIT_TOOLS = new Set(["edit", "write", "notebookedit", "multiedit", "apply_patch"])

// Whether a tool writes to files. Needed in the core rather than left to claude's
// matcher: opencode's tool.execute.after fires for EVERY tool, so without this the hook
// would shell out to git on every read and grep too. Exact names rather than a substring
// test — opencode's `todowrite` would otherwise count as a file write.
export function isEditTool(tool: string): boolean {
    return EDIT_TOOLS.has(tool.toLowerCase())
}

// The nudge itself. Advisory — it states the measured size and the reason a big
// uncommitted diff is expensive (the user reviews locally before every commit), then
// leaves the judgment of whether this is a clean boundary to the agent.
export function nudgeText(lines: number, files: number): string {
    return (
        `Uncommitted churn is now ${lines} reviewable lines across ${files} file(s), past the ` +
        `${MIN_LINES}-line mark where a diff stops being reviewable in one sitting. The user reviews ` +
        `locally before every commit, so a diff this size blocks them rather than the other way round. ` +
        `If you are at a natural boundary, stop writing and hand back the slice you have — what changed, ` +
        `what it does, what to look at first — so it can be reviewed and committed before you continue. ` +
        `If you are mid-cycle (failing test, half-applied refactor), finish that and hand back at the ` +
        `next green instead. Nothing is blocked; this is a size report, not a permission error.`
    )
}

// Dedup state, shared by both targets so switching tools mid-task doesn't re-nudge at the
// same bucket.
const STATE = join(homedir(), ".claude/cache/comprehension-nudge.json")

async function numstat(cwd: string, cached: boolean): Promise<string> {
    try {
        const args = ["-C", cwd, "diff", "--numstat", ...(cached ? ["--cached"] : [])]
        const { stdout } = await exec("git", args, { timeout: 8000 })
        return stdout
    } catch {
        return ""
    }
}

// Worktree + index churn. Both are diffs against HEAD's content, so anything committed
// drops out — a commit is what resets the counter.
async function changedLines(cwd: string): Promise<{ lines: number; files: string[] }> {
    const files = new Set<string>()
    let lines = 0
    for (const cached of [false, true]) {
        const r = parseNumstat(await numstat(cwd, cached))
        r.files.forEach((f) => files.add(f))
        lines += r.lines
    }
    return { lines, files: [...files] }
}

function alreadyNudged(cwd: string, sig: string): boolean {
    let state: Record<string, string> = {}
    try {
        state = JSON.parse(readFileSync(STATE, "utf8"))
    } catch {
        state = {}
    }
    if (state[cwd] === sig) return true
    state[cwd] = sig
    try {
        mkdirSync(dirname(STATE), { recursive: true })
        writeFileSync(STATE, JSON.stringify(state))
    } catch {
        // best-effort; a write failure just means we may re-nudge later
    }
    return false
}

export async function run(input: HookInput, ctx: HookCtx): Promise<HookResult> {
    if (!isEditTool(input.tool ?? "")) return { kind: "none" }
    const cwd = input.cwd || ctx.directory
    const { lines, files } = await changedLines(cwd)
    if (lines < MIN_LINES) return { kind: "none" }
    if (alreadyNudged(cwd, signature(cwd, files, lines))) return { kind: "none" }
    return { kind: "context", text: nudgeText(lines, files.length) }
}
