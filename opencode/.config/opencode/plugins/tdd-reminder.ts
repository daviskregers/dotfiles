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
import { statSync } from "node:fs"
import { dirname, extname } from "node:path"

const exec = promisify(execFile)

// Soft TDD nudge: editing a source file (code ext, not a test) in a git repo where
// NO test file is currently modified/staged → remind to follow red-green-refactor.
// NUDGES, never blocks. FAIL-OPEN: any error → none.

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
// Match test/spec as path SEGMENTS, not substrings (latest.py isn't a test).
const TEST_RE = /(^|[/_.\-])(tests?|specs?|__tests__)([/_.\-]|$)/i

const REMINDER =
    "TDD is default (global rule): before changing this source, there should be " +
    "a failing test that exercises the new/changed behavior — no test file is " +
    "currently modified in this repo. Red-green-refactor + rollback + contract-" +
    "migration mechanics live in the `tdd` skill; load it before proceeding, or " +
    "confirm this change is genuinely exempt (pure rename, generated code, config)."

function isTestPath(p: string): boolean {
    return TEST_RE.test(p)
}

function isSourceExt(p: string): boolean {
    return SRC_EXT.has(extname(p).toLowerCase())
}

// A test file appears among the porcelain-status paths (strip the XY status prefix).
function hasTestInStatus(porcelain: string): boolean {
    for (const line of porcelain.split("\n")) {
        const path = line.slice(3).trim()
        if (path && isTestPath(path)) return true
    }
    return false
}

function isDir(p: string): boolean {
    try {
        return statSync(p).isDirectory()
    } catch {
        return false
    }
}

async function repoRoot(path: string): Promise<string | null> {
    const d = isDir(path) ? path : dirname(path) || "."
    try {
        const { stdout } = await exec("git", ["-C", d, "rev-parse", "--show-toplevel"], { timeout: 5000 })
        return stdout.trim() || null
    } catch {
        return null // not a git repo → no nudge
    }
}

async function hasModifiedTests(root: string): Promise<boolean> {
    try {
        const { stdout } = await exec("git", ["-C", root, "status", "--porcelain"], { timeout: 5000 })
        return hasTestInStatus(stdout)
    } catch {
        return true // can't tell → assume yes, stay quiet (fail-open)
    }
}

async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
    const path = input.filePath
    if (typeof path !== "string" || !path) return { kind: "none" }
    if (!isSourceExt(path) || isTestPath(path)) return { kind: "none" }
    const root = await repoRoot(path)
    if (!root || (await hasModifiedTests(root))) return { kind: "none" }
    return { kind: "context", text: REMINDER }
}

export const tddReminder = async ({ directory }: { directory: string }) => ({
    "tool.execute.after": async (input: any, output: any) =>
        applyOpencodeAfter(output, await run(extractOpencodeAfter(input, output), { directory })),
})
