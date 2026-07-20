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

const exec = promisify(execFile)

// After a `git push`, if the branch has an open PR, remind to refresh its stale
// title/body via the pr-describer agent. Reminder only, never blocks. FAIL-OPEN:
// any error (no gh, no PR, not a repo) → none.

const PUSH = /\bgit\s+push\b/

function isGitPush(cmd: string): boolean {
    return PUSH.test(cmd)
}

function refreshContext(url: string): string {
    return (
        `Push landed and this branch has an open PR (${url}). Its diff changed, ` +
        `so the description is now stale — delegate a refresh of the title/body ` +
        `to the \`pr-describer\` agent (never edit the description inline).`
    )
}

async function run(input: HookInput, ctx: HookCtx): Promise<HookResult> {
    const cmd = input.command
    if (typeof cmd !== "string" || !isGitPush(cmd)) return { kind: "none" }
    try {
        const { stdout } = await exec("gh", ["pr", "view", "--json", "url,number"], {
            cwd: ctx.directory,
            timeout: 15000,
        })
        const url = JSON.parse(stdout).url
        return url ? { kind: "context", text: refreshContext(url) } : { kind: "none" }
    } catch {
        return { kind: "none" }
    }
}

async function main() {
    const data = JSON.parse(await Bun.stdin.text())
    const r = await run(extractClaudeInput("PostToolUse", data), {
        directory: process.env.PROJECT_DIR || process.cwd(),
    })
    const out = serializeClaudeResult("PostToolUse", r)
    if (out) process.stdout.write(out)
}
main().catch(() => {})
