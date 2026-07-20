import { test, expect } from "bun:test"
import { parseNumstat, signature } from "../comprehension-nudge"

test("parseNumstat sums churn over source files, skips non-source + generated", () => {
    // IGNORE requires surrounding slashes (/dist/), matching the original — a nested
    // dist path is excluded; churn counts only src/a.ts + pkg/b.go.
    const out = ["10\t5\tsrc/a.ts", "3\t2\tREADME.md", "40\t0\tpkg/b.go", "9\t9\tapp/dist/bundle.js", "1\t0\tyarn.lock"].join("\n")
    const r = parseNumstat(out)
    expect(r.files.sort()).toEqual(["pkg/b.go", "src/a.ts"])
    expect(r.lines).toBe(10 + 5 + 40) // README/dist/lock excluded
})

test("parseNumstat treats binary '-' churn as 0", () => {
    const r = parseNumstat("-\t-\tsrc/img.ts")
    expect(r.files).toEqual(["src/img.ts"])
    expect(r.lines).toBe(0)
})

test("signature is stable for same file-set + churn bucket, changes across buckets", () => {
    const a = signature("/repo", ["src/a.ts", "src/b.ts"], 210)
    const b = signature("/repo", ["src/b.ts", "src/a.ts"], 260) // reordered, same 100-bucket (2)
    const c = signature("/repo", ["src/a.ts", "src/b.ts"], 320) // bucket 3
    expect(a).toBe(b)
    expect(a).not.toBe(c)
})

test("signature differs by cwd", () => {
    expect(signature("/repo1", ["x.ts"], 200)).not.toBe(signature("/repo2", ["x.ts"], 200))
})
