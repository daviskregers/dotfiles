// Neutral hook result — each target adapter translates it: claude serializes to
// its stdout schema, opencode maps to throw / output mutation / message part.
type HookResult =
    | { kind: "allow"; updatedInput?: Record<string, unknown> }
    | { kind: "deny"; reason: string }
    | { kind: "context"; text: string }
    | { kind: "block"; reason: string }
    | { kind: "none" }

// Injected per target: shell + base dir (claude: node child_process/cwd; opencode: $ / directory).
type HookCtx = { directory: string }

// Normalized hook input — each target's entrypoint fills the fields its event carries.
type HookInput = {
    tool?: string
    command?: string
    filePath?: string // normalized: claude tool_input.file_path / opencode args.filePath
    toolInput?: Record<string, unknown>
    toolResponse?: unknown
    prompt?: string
    stopHookActive?: boolean
    cwd?: string
}

// ---- claude adapters: map its stdin event → HookInput, and HookResult → stdout ----
// Pure (no IO) so the generated entrypoint is thin plumbing and the real branching
// lives here under test.

function extractClaudeInput(event: string, data: any): HookInput {
    switch (event) {
        case "PreToolUse":
            return {
                tool: data.tool_name,
                command: data.tool_input?.command,
                filePath: data.tool_input?.file_path,
                toolInput: data.tool_input,
            }
        case "PostToolUse":
            return { tool: data.tool_name, command: data.tool_input?.command, toolResponse: data.tool_response }
        case "UserPromptSubmit":
            return { prompt: data.prompt }
        case "Stop":
            return { stopHookActive: data.stop_hook_active, cwd: data.cwd }
        default:
            return {}
    }
}

// Serialize to claude's stdout schema. Returns "" for none (nothing written).
function serializeClaudeResult(event: string, r: HookResult): string {
    switch (r.kind) {
        case "deny":
            return JSON.stringify({
                hookSpecificOutput: {
                    hookEventName: event,
                    permissionDecision: "deny",
                    permissionDecisionReason: r.reason,
                },
            })
        case "allow":
            return JSON.stringify({
                hookSpecificOutput: { hookEventName: event, permissionDecision: "allow", updatedInput: r.updatedInput },
            })
        case "context":
            return JSON.stringify({ hookSpecificOutput: { hookEventName: event, additionalContext: r.text } })
        case "block":
            return JSON.stringify({ decision: "block", reason: r.reason })
        default:
            return ""
    }
}

// ---- opencode adapters: extract HookInput from a plugin event, apply HookResult ----

const extractOpencodeBefore = (input: any, output: any): HookInput => ({
    tool: input.tool,
    command: output.args?.command,
    toolInput: output.args,
})

const extractOpencodeAfter = (input: any, output: any): HookInput => ({
    tool: input.tool,
    command: input.args?.command,
    filePath: input.args?.filePath ?? input.args?.file_path,
    toolResponse: output.output,
})

const extractOpencodeMessage = (_input: any, output: any): HookInput => ({
    prompt: (output.parts ?? [])
        .filter((p: any) => p.type === "text")
        .map((p: any) => p.text)
        .join(""),
})

// tool.execute.before: deny blocks the tool (throw), allow rewrites its args.
function applyOpencodeBefore(output: any, r: HookResult): void {
    if (r.kind === "deny") throw new Error(r.reason)
    if (r.kind === "allow" && r.updatedInput) Object.assign(output.args ?? {}, r.updatedInput)
}

// tool.execute.after: context appends to the tool's output.
function applyOpencodeAfter(output: any, r: HookResult): void {
    if (r.kind === "context") output.output = (output.output ?? "") + "\n\n" + r.text
}

// chat.message: context appends a text part to the message.
function applyOpencodeMessage(output: any, r: HookResult): void {
    if (r.kind === "context") output.parts.push({ type: "text", text: r.text })
}

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

async function main() {
    const data = JSON.parse(await Bun.stdin.text())
    const r = await run(extractClaudeInput("Stop", data), { directory: process.env.PROJECT_DIR || process.cwd() })
    const out = serializeClaudeResult("Stop", r)
    if (out) process.stdout.write(out)
}
main().catch(() => {})
