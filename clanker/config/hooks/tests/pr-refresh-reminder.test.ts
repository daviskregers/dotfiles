import { test, expect } from "bun:test"
import { isGitPush, refreshContext, run } from "../pr-refresh-reminder"

test.each([
    ["plain push", "git push"],
    ["push with remote", "git push origin main"],
    ["push after &&", "git commit -m x && git push -u origin feat"],
])("git push detected: %s", (_l, cmd) => {
    expect(isGitPush(cmd)).toBe(true)
})

test.each([
    ["status", "git status"],
    ["pushd (not git push)", "pushd /tmp"],
    ["commit only", "git commit -m x"],
])("not a git push: %s", (_l, cmd) => {
    expect(isGitPush(cmd)).toBe(false)
})

test("refreshContext names the url + pr-describer", () => {
    const c = refreshContext("https://github.com/o/r/pull/7")
    expect(c).toContain("https://github.com/o/r/pull/7")
    expect(c).toContain("pr-describer")
})

test("run returns none for a non-push command (no shell call)", async () => {
    expect((await run({ command: "git status" }, { directory: "." })).kind).toBe("none")
    expect((await run({}, { directory: "." })).kind).toBe("none")
})
