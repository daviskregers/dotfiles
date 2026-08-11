import { test, expect, describe } from "bun:test"
import { ensureNotice, stripBranded, commandView, rewriteCommand, run } from "../ai-attribution"

const NOTICE = "🤖 Generated with AI"

describe("ensureNotice", () => {
    test("appends notice to a plain body", () => {
        expect(ensureNotice("hello")).toBe(`hello\n\n${NOTICE}`)
    })
    test("does not double when already attributed (bare)", () => {
        expect(ensureNotice(`done\n\n${NOTICE}`)).toBe(`done\n\n${NOTICE}`)
    })
    test("does not double the (model) form", () => {
        const t = `done\n\n${NOTICE} (opus)`
        expect(ensureNotice(t)).toBe(t)
    })
    test("empty body → just the notice", () => {
        expect(ensureNotice("")).toBe(NOTICE)
    })
    test("strips a Co-Authored-By trailer then attributes", () => {
        expect(ensureNotice("msg\n\nCo-Authored-By: Claude <x@y>")).toBe(`msg\n\n${NOTICE}`)
    })
})

describe("stripBranded", () => {
    test("removes 'Generated with Claude Code' line", () => {
        expect(stripBranded("body\n\n🤖 Generated with Claude Code")).toBe("body")
    })
})

describe("rewriteCommand", () => {
    test("git commit -m → appends a -m notice", () => {
        const r = rewriteCommand('git commit -m "fix bug"')
        expect(r.action).toBe("change")
        if (r.action === "change") expect(r.cmd).toBe(`git commit -m "fix bug" -m "${NOTICE}"`)
    })
    test("editor-driven commit (no -m) → none", () => {
        expect(rewriteCommand("git commit").action).toBe("none")
    })
    test("file-based commit (-F) → deny", () => {
        expect(rewriteCommand("git commit -F msg.txt").action).toBe("deny")
    })
    test("branded text UNQUOTED in the command view → deny", () => {
        // outside quotes it survives the structural view → treated as a real trailer
        expect(rewriteCommand("git commit -m x && echo generated with claude code").action).toBe("deny")
    })
    test("branded text inside a quoted -m message → change (view drops quotes; prose isn't a trailer)", () => {
        // faithful to the original: CMD_BRANDED scans the structural view, so a
        // Co-Authored-By INSIDE a quoted message is not denied — it just gets a notice
        // appended (the branded quoted arg is not stripped from commands). See NOTE.
        expect(rewriteCommand('git commit -m "x" -m "Co-Authored-By: Claude"').action).toBe("change")
    })
    test("gh pr create --body → notice appended as a concatenated segment at the end", () => {
        const r = rewriteCommand('gh pr create --title t --body "summary"')
        expect(r.action).toBe("change")
        // appended after the body word, so the shell concatenates it onto the end
        if (r.action === "change") expect(r.cmd).toBe(`gh pr create --title t --body "summary""\n\n${NOTICE}"`)
    })
    test("single-quoted body with an escaped '\\'' apostrophe → notice at end, not mid-body", () => {
        // regression: the old regex closed at the first ' of the '\'' escape and
        // spliced the notice into the middle of the body
        const cmd = "gh pr create --body 'the school'\\''s own model'"
        const r = rewriteCommand(cmd)
        expect(r.action).toBe("change")
        if (r.action === "change") {
            expect(r.cmd).toBe(cmd + `"\n\n${NOTICE}"`)
            expect(r.cmd).not.toContain(`school\n\n${NOTICE}`) // not spliced at the apostrophe
        }
    })
    test("double-quoted body with escaped inner quotes → notice at end", () => {
        const cmd = 'gh pr create --body "New \\"Login page source\\" section"'
        const r = rewriteCommand(cmd)
        expect(r.action).toBe("change")
        if (r.action === "change") expect(r.cmd).toBe(cmd + `"\n\n${NOTICE}"`)
    })
    test("--body with a following flag → notice attaches to the body word only", () => {
        const r = rewriteCommand('gh pr create --body "sum" --label bug')
        expect(r.action).toBe("change")
        if (r.action === "change") expect(r.cmd).toBe(`gh pr create --body "sum""\n\n${NOTICE}" --label bug`)
    })
    test("gh pr create --body-file → deny", () => {
        expect(rewriteCommand("gh pr create --body-file body.md").action).toBe("deny")
    })
    test("non-commit / non-gh command → none", () => {
        expect(rewriteCommand("ls -la").action).toBe("none")
    })
    test("already-noticed command → none (idempotent)", () => {
        expect(rewriteCommand(`git commit -m "x" -m "${NOTICE}"`).action).toBe("none")
    })
    test("commit as heredoc data isn't mistaken for the real command", () => {
        // `git commit` appears only inside a quoted echo arg → structural view drops it
        expect(rewriteCommand(`echo "run git commit later"`).action).toBe("none")
    })
})

// Decode the real body a shell would pass to `gh`, by running the rewritten
// `--body <arg>` through `printf`. This is the airtight check that the notice is
// a strict suffix and the body's middle survives intact — not just that some
// substring appears in the command text.
function decodeBody(cmd: string): string {
    const prefix = "gh pr create --body "
    const arg = cmd.slice(prefix.length) // tests below keep --body as the last arg
    const p = Bun.spawnSync(["sh", "-c", `printf '%s' ${arg}`])
    return new TextDecoder().decode(p.stdout)
}

describe("gh body: notice is a strict suffix, never mid-body (real-shell decode)", () => {
    const cases: Array<[string, string, string]> = [
        // [label, command, intended body before attribution]
        ["single quotes, no specials", `gh pr create --body 'simple summary'`, "simple summary"],
        ["apostrophe in the middle", `gh pr create --body 'the school'\\''s own model'`, "the school's own model"],
        [
            "two apostrophes, text after each",
            `gh pr create --body 'it'\\''s the school'\\''s page'`,
            "it's the school's page",
        ],
        [
            "double quotes with an escaped quote in the MIDDLE",
            `gh pr create --body "New \\"Login page source\\" section in file"`,
            'New "Login page source" section in file',
        ],
        [
            "double-quoted body ending mid-sentence before more prose",
            `gh pr create --body "before \\"quoted\\" and a lot more text after"`,
            'before "quoted" and a lot more text after',
        ],
        [
            "mixed concatenation: double + single segments",
            `gh pr create --body "quote: \\"x\\" "'and the org'\\''s name'`,
            "quote: \"x\" and the org's name",
        ],
    ]
    for (const [label, cmd, body] of cases) {
        test(label, () => {
            const r = rewriteCommand(cmd)
            expect(r.action).toBe("change")
            if (r.action !== "change") return
            const decoded = decodeBody(r.cmd)
            // the notice sits at the very end...
            expect(decoded).toBe(`${body}\n\n${NOTICE}`)
            // ...and appears exactly once, as a suffix — not spliced into the middle
            expect(decoded.indexOf(NOTICE)).toBe(decoded.length - NOTICE.length)
            expect(decoded.split(NOTICE).length - 1).toBe(1)
            // the original body is preserved unbroken ahead of it
            expect(decoded.startsWith(body)).toBe(true)
        })
    }
})

describe("commandView", () => {
    test("drops quoted strings so embedded keywords aren't seen", () => {
        expect(commandView(`echo "git commit -m x"`)).not.toContain("commit")
    })
})

describe("run — structured tools (FIELD_MAP, exact tool names)", () => {
    test("claude custom-tools update_pr_info (hyphenated) gets attributed", async () => {
        const r = await run(
            { tool: "mcp__custom-tools__update_pr_info", toolInput: { body: "desc" } },
            { directory: "." },
        )
        expect(r.kind).toBe("allow")
        if (r.kind === "allow") expect((r.updatedInput as any).body).toBe(`desc\n\n${NOTICE}`)
    })
    test("claude Linear save_issue attributes the description field", async () => {
        const r = await run(
            { tool: "mcp__claude_ai_Linear__save_issue", toolInput: { description: "d" } },
            { directory: "." },
        )
        expect(r.kind).toBe("allow")
        if (r.kind === "allow") expect((r.updatedInput as any).description).toBe(`d\n\n${NOTICE}`)
    })
    test("opencode update-pr-info attributes body", async () => {
        const r = await run({ tool: "update-pr-info", toolInput: { body: "d" } }, { directory: "." })
        expect(r.kind).toBe("allow")
    })
    test("already-attributed body → none", async () => {
        const r = await run({ tool: "update-pr-info", toolInput: { body: `d\n\n${NOTICE}` } }, { directory: "." })
        expect(r.kind).toBe("none")
    })
    test("empty body → none", async () => {
        expect((await run({ tool: "update-pr-info", toolInput: { body: "  " } }, { directory: "." })).kind).toBe("none")
    })
})

describe("run — Bash", () => {
    test("commit -m → allow with rewritten command", async () => {
        const r = await run(
            { tool: "Bash", command: 'git commit -m "x"', toolInput: { command: 'git commit -m "x"' } },
            { directory: "." },
        )
        expect(r.kind).toBe("allow")
        if (r.kind === "allow") expect((r.updatedInput as any).command).toContain(NOTICE)
    })
    test("file-based commit → deny", async () => {
        expect((await run({ tool: "bash", command: "git commit -F m.txt" }, { directory: "." })).kind).toBe("deny")
    })
    test("innocuous command → none", async () => {
        expect((await run({ tool: "Bash", command: "ls" }, { directory: "." })).kind).toBe("none")
    })
})
