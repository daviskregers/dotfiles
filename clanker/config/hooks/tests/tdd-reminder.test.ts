import { test, expect } from "bun:test"
import { isTestPath, isSourceExt, hasTestInStatus, run } from "../tdd-reminder"

test.each([
    ["tests dir", "src/tests/foo.py"],
    ["spec suffix", "app/user.spec.ts"],
    ["__tests__", "pkg/__tests__/x.js"],
    ["_test suffix", "internal/gen_test.go"],
])("test path: %s", (_l, p) => expect(isTestPath(p)).toBe(true))

test.each([
    ["latest not test", "src/latest.py"],
    ["inspector not spec", "lib/inspector.py"],
    ["plain source", "src/user.ts"],
])("not a test path: %s", (_l, p) => expect(isTestPath(p)).toBe(false))

test.each([
    ["ts", "a/b.ts", true],
    ["go", "main.go", true],
    ["markdown", "README.md", false],
    ["json config", "tsconfig.json", false],
])("source ext %s", (_l, p, want) => expect(isSourceExt(p)).toBe(want))

test("hasTestInStatus finds a test among porcelain lines", () => {
    expect(hasTestInStatus(" M src/foo.ts\n?? src/foo.test.ts")).toBe(true)
    expect(hasTestInStatus(" M src/foo.ts\n M src/bar.ts")).toBe(false)
    expect(hasTestInStatus("")).toBe(false)
})

test("run ignores non-source + test files without touching git", async () => {
    expect((await run({ filePath: "README.md" }, { directory: "." })).kind).toBe("none")
    expect((await run({ filePath: "src/foo.test.ts" }, { directory: "." })).kind).toBe("none")
    expect((await run({}, { directory: "." })).kind).toBe("none")
})
