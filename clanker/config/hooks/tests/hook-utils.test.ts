import { test, expect, describe } from "bun:test"
import {
    extractClaudeInput,
    serializeClaudeResult,
    extractOpencodeBefore,
    extractOpencodeAfter,
    extractOpencodePrompt,
    applyOpencodeBefore,
    applyOpencodeAfter,
    applyOpencodePrompt,
    injectOnIdle,
    type HookResult,
} from "../hook-utils"

describe("extractClaudeInput", () => {
    test("PreToolUse pulls tool + command + filePath + toolInput", () => {
        const d = { tool_name: "Edit", tool_input: { file_path: "src/a.ts" } }
        expect(extractClaudeInput("PreToolUse", d)).toEqual({
            tool: "Edit",
            command: undefined,
            filePath: "src/a.ts",
            toolInput: { file_path: "src/a.ts" },
        })
    })
    test("PreToolUse carries cwd, so a hook can measure the repo it fired in", () => {
        const d = { tool_name: "Edit", tool_input: { file_path: "src/a.ts" }, cwd: "/repo" }
        expect(extractClaudeInput("PreToolUse", d).cwd).toBe("/repo")
    })
    test("PostToolUse pulls toolResponse", () => {
        const d = { tool_name: "Bash", tool_input: { command: "ls" }, tool_response: "out" }
        expect(extractClaudeInput("PostToolUse", d)).toEqual({ tool: "Bash", command: "ls", toolResponse: "out" })
    })
    test("UserPromptSubmit pulls prompt", () => {
        expect(extractClaudeInput("UserPromptSubmit", { prompt: "hey" })).toEqual({ prompt: "hey" })
    })
    test("Stop pulls stopHookActive + cwd", () => {
        expect(extractClaudeInput("Stop", { stop_hook_active: true, cwd: "/x" })).toEqual({
            stopHookActive: true,
            cwd: "/x",
        })
    })
    test("missing tool_input does not throw", () => {
        expect(extractClaudeInput("PreToolUse", {})).toEqual({
            tool: undefined,
            command: undefined,
            toolInput: undefined,
        })
    })
})

describe("serializeClaudeResult", () => {
    test("deny → permissionDecision deny with reason + event", () => {
        const out = JSON.parse(serializeClaudeResult("PreToolUse", { kind: "deny", reason: "no" }))
        expect(out.hookSpecificOutput).toEqual({
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "no",
        })
    })
    test("allow → permissionDecision allow with updatedInput", () => {
        const out = JSON.parse(serializeClaudeResult("PreToolUse", { kind: "allow", updatedInput: { command: "x" } }))
        expect(out.hookSpecificOutput.permissionDecision).toBe("allow")
        expect(out.hookSpecificOutput.updatedInput).toEqual({ command: "x" })
    })
    test("context → additionalContext", () => {
        const out = JSON.parse(serializeClaudeResult("UserPromptSubmit", { kind: "context", text: "ctx" }))
        expect(out.hookSpecificOutput).toEqual({ hookEventName: "UserPromptSubmit", additionalContext: "ctx" })
    })
    test("block → decision block (Stop)", () => {
        expect(JSON.parse(serializeClaudeResult("Stop", { kind: "block", reason: "wait" }))).toEqual({
            decision: "block",
            reason: "wait",
        })
    })
    test("none → empty string (nothing written)", () => {
        expect(serializeClaudeResult("PreToolUse", { kind: "none" })).toBe("")
    })
})

describe("extractOpencodeBefore", () => {
    test("before: tool + command + toolInput from the one event", () => {
        expect(extractOpencodeBefore({ tool: "bash", input: { command: "rm x" } })).toEqual({
            tool: "bash",
            command: "rm x",
            toolInput: { command: "rm x" },
        })
    })
    test("before: an event carrying no input does not throw", () => {
        expect(extractOpencodeBefore({ tool: "bash" })).toEqual({
            tool: "bash",
            command: undefined,
            toolInput: undefined,
        })
    })
})

describe("extractOpencodeAfter", () => {
    test("after: tool + command from input, response from the result content", () => {
        expect(extractOpencodeAfter({ tool: "bash", input: { command: "ls" }, result: { content: "res" } })).toEqual({
            tool: "bash",
            command: "ls",
            filePath: undefined,
            toolResponse: "res",
        })
    })
    test("after: an errored call carries no result, so nothing to report", () => {
        expect(extractOpencodeAfter({ tool: "bash", error: { message: "boom" } }).toolResponse).toBeUndefined()
    })
    test("after: filePath from opencode camelCase input", () => {
        expect(extractOpencodeAfter({ tool: "edit", input: { filePath: "src/a.ts" } }).filePath).toBe("src/a.ts")
    })
})

describe("applyOpencodeBefore", () => {
    test("deny throws with reason", () => {
        expect(() => applyOpencodeBefore({ input: {} }, { kind: "deny", reason: "blocked" })).toThrow("blocked")
    })
    test("allow merges updatedInput into the event's tool input", () => {
        const event = { input: { command: "old", keep: 1 } }
        applyOpencodeBefore(event, { kind: "allow", updatedInput: { command: "new" } })
        expect(event.input).toEqual({ command: "new", keep: 1 })
    })
    test("none is a no-op", () => {
        const event = { input: { command: "x" } }
        expect(() => applyOpencodeBefore(event, { kind: "none" })).not.toThrow()
        expect(event.input).toEqual({ command: "x" })
    })
})

describe("applyOpencodeAfter", () => {
    test("context appends to a string result content", () => {
        const event = { result: { content: "orig" } }
        applyOpencodeAfter(event, { kind: "context", text: "extra" })
        expect(event.result.content).toBe("orig\n\nextra")
    })
    test("context pushes a text block onto array content", () => {
        const event = { result: { content: [{ type: "text", text: "orig" }] } }
        applyOpencodeAfter(event, { kind: "context", text: "extra" })
        expect(event.result.content).toEqual([
            { type: "text", text: "orig" },
            { type: "text", text: "extra" },
        ])
    })
    test("context supplies content when the tool returned none", () => {
        const event: any = { result: {} }
        applyOpencodeAfter(event, { kind: "context", text: "extra" })
        expect(event.result.content).toBe("extra")
    })
    test("an errored call has no result to append to", () => {
        const event: any = { error: { message: "boom" } }
        expect(() => applyOpencodeAfter(event, { kind: "context", text: "extra" })).not.toThrow()
        expect(event).toEqual({ error: { message: "boom" } })
    })
    test("none leaves content untouched", () => {
        const event = { result: { content: "orig" } }
        applyOpencodeAfter(event, { kind: "none" })
        expect(event.result.content).toBe("orig")
    })
})

describe("extractOpencodePrompt", () => {
    test("prompt: takes the draft's text", () => {
        expect(extractOpencodePrompt({ prompt: { text: "hey" } })).toEqual({ prompt: "hey" })
    })
    test("prompt: a draft with no text yields an empty prompt", () => {
        expect(extractOpencodePrompt({})).toEqual({ prompt: "" })
    })
})

describe("applyOpencodePrompt", () => {
    test("context appends to the draft's text", () => {
        const event = { prompt: { text: "hey" } }
        applyOpencodePrompt(event, { kind: "context", text: "note" })
        expect(event.prompt.text).toBe("hey\n\nnote")
    })
    test("none leaves the draft untouched", () => {
        const event = { prompt: { text: "hey" } }
        applyOpencodePrompt(event, { kind: "none" })
        expect(event.prompt.text).toBe("hey")
    })
})

describe("injectOnIdle", () => {
    const mkCtx = () => {
        const calls: any[] = []
        return { calls, session: { prompt: async (opts: any) => calls.push(opts) } }
    }
    test("block injects the reason as a prompt to the session", async () => {
        const ctx = mkCtx()
        expect(await injectOnIdle(ctx, "sess-1", { kind: "block", reason: "checkpoint" })).toBe(true)
        expect(ctx.calls).toEqual([{ sessionID: "sess-1", text: "checkpoint" }])
    })
    test("context injects its text", async () => {
        const ctx = mkCtx()
        expect(await injectOnIdle(ctx, "s", { kind: "context", text: "note" })).toBe(true)
        expect(ctx.calls[0].text).toBe("note")
    })
    test("none injects nothing", async () => {
        const ctx = mkCtx()
        expect(await injectOnIdle(ctx, "s", { kind: "none" })).toBe(false)
        expect(ctx.calls).toHaveLength(0)
    })
})
