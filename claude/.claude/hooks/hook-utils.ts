// Neutral hook result — each target adapter translates it: claude serializes to
// its stdout schema, opencode maps to throw / output mutation / message part.
export type HookResult =
    | { kind: "allow"; updatedInput?: Record<string, unknown> }
    | { kind: "deny"; reason: string }
    | { kind: "context"; text: string }
    | { kind: "block"; reason: string }
    | { kind: "none" }

// Injected per target: shell + base dir (claude: node child_process/cwd; opencode: $ / directory).
export type HookCtx = { directory: string }

// Normalized hook input — each target's entrypoint fills the fields its event carries.
export type HookInput = {
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

export function extractClaudeInput(event: string, data: any): HookInput {
    switch (event) {
        case "PreToolUse":
            return {
                tool: data.tool_name,
                command: data.tool_input?.command,
                filePath: data.tool_input?.file_path,
                toolInput: data.tool_input,
                cwd: data.cwd,
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
export function serializeClaudeResult(event: string, r: HookResult): string {
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

// ---- opencode adapters: map a V2 plugin event → HookInput, and HookResult → that
// event's mutable surface. V2 registers each hook on the domain that owns it and
// hands the callback ONE mutable event, so there is no input/output pair to bridge.

export const extractOpencodeBefore = (event: any): HookInput => ({
    tool: event.tool,
    command: event.input?.command,
    toolInput: event.input,
})

export const extractOpencodeAfter = (event: any): HookInput => ({
    tool: event.tool,
    command: event.input?.command,
    filePath: event.input?.filePath ?? event.input?.file_path,
    toolResponse: event.result?.content,
})

// session.hook("prompt"): the hook owns a mutable draft of the prompt being admitted.
export const extractOpencodePrompt = (event: any): HookInput => ({
    prompt: event.prompt?.text ?? "",
})

// tool.hook("execute.before"): deny blocks the tool by throwing; allow rewrites the
// event's tool input in place.
export function applyOpencodeBefore(event: any, r: HookResult): void {
    if (r.kind === "deny") throw new Error(r.reason)
    if (r.kind === "allow" && r.updatedInput) Object.assign(event.input ?? {}, r.updatedInput)
}

// tool.hook("execute.after"): the tool result is structured, so a nudge joins its
// model-visible content — a string, a Content array, or nothing at all. An errored
// call carries no result, so there is nowhere to append and the hook stays a no-op.
export function applyOpencodeAfter(event: any, r: HookResult): void {
    if (r.kind !== "context") return
    const result = event?.result
    if (!result) return
    const content = result.content
    if (typeof content === "string") result.content = content + "\n\n" + r.text
    else if (Array.isArray(content)) content.push({ type: "text", text: r.text })
    else result.content = r.text
}

// session.hook("prompt"): V2 exposes no typed rejection on admission — the hook
// transforms input — so only a context result does anything here.
export function applyOpencodePrompt(event: any, r: HookResult): void {
    if (r.kind !== "context") return
    event.prompt.text = `${event.prompt.text ?? ""}\n\n${r.text}`
}

// session.idle arrives on the event stream, which can neither block nor mutate the turn
// that already ended — so a block/context result is injected as a prompt, which
// re-activates the turn so the agent addresses it. Returns whether it injected (for
// testing).
export async function injectOnIdle(ctx: any, sessionID: string, r: HookResult): Promise<boolean> {
    const text = r.kind === "block" ? r.reason : r.kind === "context" ? r.text : ""
    if (!text) return false
    await ctx.session.prompt({ sessionID, text })
    return true
}
