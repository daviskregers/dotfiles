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

// Nudge when a prompt looks like a bare problem dump: references an artifact
// (URL or error/log paste), states NO hypothesis, and is short enough to be a
// dump rather than a considered report. Pure heuristic → context (never blocks).

const URL = /https?:\/\//i
const ERROR_MARKER = /\b(error|exception|traceback|stack ?trace|failed|failing|fatal|panic)\b/i
// Markers that the user has already done some thinking / posed a question.
const HYPOTHESIS =
    /(\?|\bi think\b|\bi suspect\b|\bi bet\b|\bbecause\b|\bhypothes|\brule[d]? out\b|\bmaybe\b|\bcould be\b|\bmight be\b|\bmy guess\b|\bseems like\b|\bprobably\b|\bwhy\b)/i

const NUDGE =
    "This prompt looks like a bare problem dump (artifact/link, no stated " +
    "hypothesis). Per the shared-reasoning rule: if the diagnosis is non-trivial, " +
    "open with your candidate hypotheses + the cheapest discriminating check and " +
    "invite a prediction before handing back a fix — keep me in the loop. If it's " +
    "genuinely trivial/mechanical, just do it."

// True when the prompt trips the dump heuristic (artifact present, no hypothesis, short).
function isBareDump(prompt: string): boolean {
    if (!prompt.trim()) return false
    if (prompt.trim().split(/\s+/).length > 120) return false // long, considered report
    if (!(URL.test(prompt) || ERROR_MARKER.test(prompt))) return false // no artifact
    if (HYPOTHESIS.test(prompt)) return false // already posed a hypothesis/question
    return true
}

async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
    const prompt = input.prompt
    if (typeof prompt !== "string" || !isBareDump(prompt)) return { kind: "none" }
    return { kind: "context", text: NUDGE }
}

export const offloadingNudge = async ({ directory }: { directory: string }) => ({
    "chat.message": async (input: any, output: any) =>
        applyOpencodeMessage(output, await run(extractOpencodeMessage(input, output), { directory })),
})
