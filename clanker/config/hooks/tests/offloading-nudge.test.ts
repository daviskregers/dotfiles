import { test, expect } from "bun:test"
import { isBareDump, run } from "../offloading-nudge"

// Ported from offloading-nudge.py — these assert the heuristic contract survives the port.
const DUMPS: [string, string][] = [
    ["url no hypothesis", "tests fail on CI https://ci.example.com/run/42"],
    ["error paste no hypothesis", "Getting a TypeError in the build, traceback below\nTypeError: x"],
    ["failing marker", "the deploy is failing, see logs"],
]
const NOT_DUMPS: [string, string][] = [
    ["has question mark", "why does https://ci.example.com fail?"],
    ["states hypothesis", "CI fails https://x — i think the JWT_SECRET env is missing"],
    ["because clause", "the build failed because the lockfile is stale https://x"],
    ["no artifact", "can you refactor this function to be cleaner"],
    ["empty", "   "],
]

test.each(DUMPS)("bare dump: %s", (_label, prompt) => {
    expect(isBareDump(prompt)).toBe(true)
})
test.each(NOT_DUMPS)("not a dump: %s", (_label, prompt) => {
    expect(isBareDump(prompt)).toBe(false)
})

test("long considered report (>120 words) is not nagged", () => {
    const long = "error " + "word ".repeat(130) + "https://x"
    expect(isBareDump(long)).toBe(false)
})

test("run emits context for a dump, none otherwise", async () => {
    expect((await run({ prompt: "build failing https://ci/x" }, { directory: "." })).kind).toBe("context")
    expect((await run({ prompt: "refactor this please" }, { directory: "." })).kind).toBe("none")
    expect((await run({}, { directory: "." })).kind).toBe("none")
})
