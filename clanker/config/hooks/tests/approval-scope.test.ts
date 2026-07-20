import { test, expect } from "bun:test"
import { isBareApproval, run } from "../approval-scope"

// Ported from approval-scope.py.
const BARE: [string, string][] = [
    ["yes", "yes"],
    ["proceed", "proceed"],
    ["go ahead", "go ahead"],
    ["lgtm", "lgtm"],
    ["ship it", "ship it"],
    ["yeah do it (<=6 words)", "yeah do it"],
    ["ok with quoted context", "> earlier: should I commit and push?\nyes"],
]
const NOT_BARE: [string, string][] = [
    ["long instruction", "yes but first rename the file and update the imports everywhere"],
    ["non-affirmation", "the tests are green now"],
    ["only quoted lines", "> yes\n> proceed"],
    ["question back", "which one did you mean?"],
]

test.each(BARE)("bare approval: %s", (_label, prompt) => {
    expect(isBareApproval(prompt)).toBe(true)
})
test.each(NOT_BARE)("not bare approval: %s", (_label, prompt) => {
    expect(isBareApproval(prompt)).toBe(false)
})

test("run emits context for bare approval, none otherwise", async () => {
    expect((await run({ prompt: "yes" }, { directory: "." })).kind).toBe("context")
    expect((await run({ prompt: "the build is green" }, { directory: "." })).kind).toBe("none")
})
