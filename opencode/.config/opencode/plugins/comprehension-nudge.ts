import { injectOnIdle, type HookResult, type HookCtx, type HookInput } from "../hook-lib/hook-utils"

import { execFile } from "node:child_process"
import { promisify } from "node:util"
import { readFileSync, writeFileSync, mkdirSync } from "node:fs"
import { homedir } from "node:os"
import { join, dirname, extname } from "node:path"
import { createHash } from "node:crypto"

const exec = promisify(execFile)

// Stop hook: when a session produced a SUBSTANTIAL source change, block the stop
// once to force an incremental comprehension checkpoint (active recall). Guards:
// stop_hook_active loop guard + diff-signature dedup (once per changed-source state
// per cwd). Only above a HIGH threshold. FAIL-OPEN: any error → allow stop.

const SRC_EXT = new Set([
    ".py",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".vue",
    ".go",
    ".rb",
    ".php",
    ".rs",
    ".java",
    ".kt",
    ".swift",
    ".c",
    ".cc",
    ".cpp",
    ".h",
    ".hpp",
    ".cs",
    ".scala",
    ".ex",
    ".exs",
    ".m",
    ".mm",
    ".lua",
])
const IGNORE = /(lock|\.min\.|generated|\/vendor\/|\/node_modules\/|\/dist\/)/i
const MIN_LINES = 150
const STATE = join(homedir(), ".claude/cache/comprehension-nudge.json")

const REASON =
    "This session changed a substantial amount of source. Before you stop, run an " +
    "incremental comprehension checkpoint (shared-reasoning rule) so this doesn't " +
    "ship as a black box: for each meaningful piece, what it does + how it fits + " +
    "the one design decision that matters + the seam most likely to bite. Frame it " +
    "as ACTIVE RECALL — ask me to predict what a piece does or where the risk is, " +
    "don't lecture. Offer `/explain` or the `tutor` agent for the complex parts, and " +
    "flag + offer `/simplify` if the design has become a ball of mud. If I already " +
    "understand it, a one-line confirmation from me is enough."

// Parse one `git diff --numstat` block → the source files touched + total churn,
// filtering non-source extensions and generated/vendored paths.
function parseNumstat(output: string): { files: string[]; lines: number } {
    let lines = 0
    const files: string[] = []
    for (const row of output.split("\n")) {
        const parts = row.split("\t")
        if (parts.length !== 3) continue
        const [added, deleted, path] = parts
        if (!SRC_EXT.has(extname(path).toLowerCase()) || IGNORE.test(path)) continue
        files.push(path)
        lines += (/^\d+$/.test(added) ? +added : 0) + (/^\d+$/.test(deleted) ? +deleted : 0)
    }
    return { files, lines }
}

// Coarse signature: same file-set + churn bucket → same sig, so we re-nudge only on
// material growth (bucket of 100 lines), not on every tiny change.
function signature(cwd: string, files: string[], lines: number): string {
    const bucket = Math.floor(lines / 100)
    const raw = cwd + "|" + [...files].sort().join("|") + `|${bucket}`
    return createHash("sha1").update(raw).digest("hex")
}

async function numstat(cwd: string, cached: boolean): Promise<string> {
    try {
        const args = ["-C", cwd, "diff", "--numstat", ...(cached ? ["--cached"] : [])]
        const { stdout } = await exec("git", args, { timeout: 8000 })
        return stdout
    } catch {
        return ""
    }
}

async function changedSource(cwd: string): Promise<{ lines: number; files: string[] }> {
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

async function run(input: HookInput, ctx: HookCtx): Promise<HookResult> {
    if (input.stopHookActive) return { kind: "none" } // already forced a continuation — don't loop
    const cwd = input.cwd || ctx.directory
    const { lines, files } = await changedSource(cwd)
    if (lines < MIN_LINES) return { kind: "none" } // not substantial
    if (alreadyNudged(cwd, signature(cwd, files, lines))) return { kind: "none" }
    return { kind: "block", reason: REASON }
}

export const comprehensionNudge = async ({ directory, client }: { directory: string; client: any }) => ({
    event: async (input: any) => {
        if (input.event?.type !== "session.idle") return
        await injectOnIdle(client, input.event.properties.sessionID, await run({}, { directory }))
    },
})
