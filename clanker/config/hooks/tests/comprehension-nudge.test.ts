import { test, expect } from "bun:test"
import {
    parseNumstat,
    signature,
    nudgeText,
    isEditTool,
    totalChurn,
    countLines,
    MIN_LINES,
} from "../comprehension-nudge"

test("parseNumstat counts churn on every path, whatever the extension", () => {
    const out = ["10\t5\tsrc/a.ts", "3\t2\tREADME.md", "40\t0\tbin/tmux-session-picker", "7\t1\tetc/nginx.conf"].join(
        "\n",
    )
    const r = parseNumstat(out)
    expect(r.files.sort()).toEqual(["README.md", "bin/tmux-session-picker", "etc/nginx.conf", "src/a.ts"])
    expect(r.lines).toBe(10 + 5 + 3 + 2 + 40 + 7 + 1)
})

test("parseNumstat excludes lock, generated, minified and vendored paths at any depth", () => {
    const out = [
        "10\t5\tsrc/a.ts",
        "1\t0\tbun.lock",
        "6\t6\tclanker/generated-manifest.json",
        "4\t4\tweb/static/app.min.js",
        "9\t9\tapp/dist/bundle.js",
        "3\t3\tdist/bundle.js",
        "8\t8\tpkg/vendor/lib.go",
        "2\t2\tnode_modules/x/index.js",
    ].join("\n")
    const r = parseNumstat(out)
    expect(r.files).toEqual(["src/a.ts"])
    expect(r.lines).toBe(15)
})

test("parseNumstat keeps source files whose names merely contain 'lock'", () => {
    const out = [
        "10\t0\tsrc/blocklist.ts",
        "5\t0\tauth/unlock.go",
        "1\t0\tbun.lock",
        "2\t0\tnvim/nvim-pack-lock.json",
    ].join("\n")
    const r = parseNumstat(out)
    expect(r.files.sort()).toEqual(["auth/unlock.go", "src/blocklist.ts"])
    expect(r.lines).toBe(15)
})

test("parseNumstat scores a binary file's '-' churn as 0, not NaN", () => {
    const r = parseNumstat(["-\t-\tassets/logo.png", "12\t0\tsrc/a.ts"].join("\n"))
    expect(r.files.sort()).toEqual(["assets/logo.png", "src/a.ts"])
    expect(r.lines).toBe(12)
})

test("signature holds within a 100-line churn bucket and changes across buckets", () => {
    const at260 = signature("/repo", ["src/a.ts", "src/b.ts"], 260)
    const reordered = signature("/repo", ["src/b.ts", "src/a.ts"], 299)
    const nextBucket = signature("/repo", ["src/a.ts", "src/b.ts"], 320)
    expect(at260).toBe(reordered)
    expect(at260).not.toBe(nextBucket)
})

test("signature is per-repo, so two checkouts with identical churn nudge separately", () => {
    expect(signature("/repo1", ["x.ts"], 260)).not.toBe(signature("/repo2", ["x.ts"], 260))
})

test("isEditTool matches the file-editing tools of both targets", () => {
    expect(isEditTool("Edit")).toBe(true)
    expect(isEditTool("Write")).toBe(true)
    expect(isEditTool("NotebookEdit")).toBe(true)
    expect(isEditTool("edit")).toBe(true)
    expect(isEditTool("write")).toBe(true)
    expect(isEditTool("apply_patch")).toBe(true)
})

test("isEditTool rejects tools that only look like writers, notably opencode's todowrite", () => {
    expect(isEditTool("todowrite")).toBe(false)
    expect(isEditTool("todoread")).toBe(false)
    expect(isEditTool("bash")).toBe(false)
    expect(isEditTool("read")).toBe(false)
    expect(isEditTool("")).toBe(false)
})

test("totalChurn counts untracked files, which git diff never reports at all", () => {
    const r = totalChurn("10\t0\tsrc/a.ts", "", [{ path: "src/new.ts", lines: 120 }])
    expect(r.files.sort()).toEqual(["src/a.ts", "src/new.ts"])
    expect(r.lines).toBe(130)
})

test("totalChurn applies the denylist to untracked files too", () => {
    const r = totalChurn("", "", [
        { path: "src/new.ts", lines: 40 },
        { path: "bun.lock", lines: 900 },
        { path: "web/vendor/lib.js", lines: 500 },
    ])
    expect(r.files).toEqual(["src/new.ts"])
    expect(r.lines).toBe(40)
})

test("countLines counts what a reviewer would read, trailing newline or not", () => {
    expect(countLines("a\nb\n")).toBe(2)
    expect(countLines("a\nb")).toBe(2)
    expect(countLines("\n")).toBe(1)
    expect(countLines("")).toBe(0)
})

test("nudgeText reports the measured churn and the review threshold", () => {
    const text = nudgeText(412, 7)
    expect(text).toContain("412")
    expect(text).toContain("7")
    expect(text).toContain(String(MIN_LINES))
})
