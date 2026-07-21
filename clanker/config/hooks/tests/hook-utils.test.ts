import { test, expect, describe } from "bun:test"
import {
    extractClaudeInput,
    serializeClaudeResult,
    extractOpencodeBefore,
    extractOpencodeAfter,
    extractOpencodeMessage,
    applyOpencodeBefore,
    applyOpencodeAfter,
    applyOpencodeMessage,
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

describe("extractOpencode*", () => {
    test("before: command from output.args", () => {
        expect(extractOpencodeBefore({ tool: "bash" }, { args: { command: "rm x" } })).toEqual({
            tool: "bash",
            command: "rm x",
            toolInput: { command: "rm x" },
        })
    })
    test("after: command from input.args, response from output.output", () => {
        expect(extractOpencodeAfter({ tool: "bash", args: { command: "ls" } }, { output: "res" })).toEqual({
            tool: "bash",
            command: "ls",
            filePath: undefined,
            toolResponse: "res",
        })
    })
    test("after: filePath from opencode camelCase args", () => {
        expect(extractOpencodeAfter({ tool: "edit", args: { filePath: "src/a.ts" } }, { output: "" }).filePath).toBe(
            "src/a.ts",
        )
    })
    test("message: concatenates text parts, ignores non-text", () => {
        const output = { parts: [{ type: "text", text: "a" }, { type: "file" }, { type: "text", text: "b" }] }
        expect(extractOpencodeMessage({}, output)).toEqual({ prompt: "ab" })
    })
    test("message: missing parts → empty prompt", () => {
        expect(extractOpencodeMessage({}, {})).toEqual({ prompt: "" })
    })
})

describe("applyOpencodeBefore", () => {
    test("deny throws with reason", () => {
        expect(() => applyOpencodeBefore({ args: {} }, { kind: "deny", reason: "blocked" })).toThrow("blocked")
    })
    test("allow merges updatedInput into args", () => {
        const output = { args: { command: "old", keep: 1 } }
        applyOpencodeBefore(output, { kind: "allow", updatedInput: { command: "new" } })
        expect(output.args).toEqual({ command: "new", keep: 1 })
    })
    test("none is a no-op", () => {
        const output = { args: { command: "x" } }
        expect(() => applyOpencodeBefore(output, { kind: "none" })).not.toThrow()
        expect(output.args).toEqual({ command: "x" })
    })
})

describe("applyOpencodeAfter", () => {
    test("context appends to output", () => {
        const output = { output: "orig" }
        applyOpencodeAfter(output, { kind: "context", text: "extra" })
        expect(output.output).toBe("orig\n\nextra")
    })
    test("none leaves output untouched", () => {
        const output = { output: "orig" }
        applyOpencodeAfter(output, { kind: "none" })
        expect(output.output).toBe("orig")
    })
})

describe("applyOpencodeMessage", () => {
    test("context pushes a text part", () => {
        const output: { parts: any[] } = { parts: [] }
        applyOpencodeMessage(output, { kind: "context", text: "note" })
        expect(output.parts).toEqual([{ type: "text", text: "note" }])
    })
    test("none pushes nothing", () => {
        const output: { parts: any[] } = { parts: [] }
        applyOpencodeMessage(output, { kind: "none" })
        expect(output.parts).toEqual([])
    })
})

describe("injectOnIdle", () => {
    const mkClient = () => {
        const calls: any[] = []
        return { calls, session: { prompt: async (opts: any) => calls.push(opts) } }
    }
    test("block injects the reason as a prompt to the session", async () => {
        const c = mkClient()
        expect(await injectOnIdle(c, "sess-1", { kind: "block", reason: "checkpoint" })).toBe(true)
        expect(c.calls).toHaveLength(1)
        expect(c.calls[0].path.id).toBe("sess-1")
        expect(c.calls[0].body.parts).toEqual([{ type: "text", text: "checkpoint" }])
    })
    test("context injects its text", async () => {
        const c = mkClient()
        expect(await injectOnIdle(c, "s", { kind: "context", text: "note" })).toBe(true)
        expect(c.calls[0].body.parts[0].text).toBe("note")
    })
    test("none injects nothing", async () => {
        const c = mkClient()
        expect(await injectOnIdle(c, "s", { kind: "none" })).toBe(false)
        expect(c.calls).toHaveLength(0)
    })
})
