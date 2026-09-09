import { test, expect, describe } from "bun:test"
import { ensureNotice, stripBranded, scanCommand, rewriteCommand, run } from "../ai-attribution"

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
    test("branded text UNQUOTED in the COMMIT itself → deny", () => {
        // outside quotes it survives the structural view → treated as a real trailer
        expect(rewriteCommand("git commit -m x --trailer generated with claude code").action).toBe("deny")
    })
    test("branded text in a SIBLING command of the chain → not the commit's problem", () => {
        // was deny: the whole-chain scan blocked a commit over text going nowhere near it
        expect(rewriteCommand("git commit -m x && echo generated with claude code").action).toBe("change")
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
            'quote: "x" and the org\'s name',
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

describe("scanCommand mask", () => {
    test("blanks quoted strings so embedded keywords aren't seen", () => {
        expect(scanCommand(`echo "git commit -m x"`)?.mask).not.toContain("commit")
    })
    test("mask is the same length as the command, so match indices map back 1:1", () => {
        const cmd = `gh pr create --title "uses --body flag" --body "real"`
        const scan = scanCommand(cmd)
        expect(scan?.mask.length).toBe(cmd.length)
        // the only surviving --body is the real flag, at its true index
        expect(scan?.mask.indexOf("--body")).toBe(cmd.lastIndexOf("--body"))
    })
})

// The notice must land on the `git commit` segment, not at the end of a chain —
// appending to the raw string put the flag on the LAST command, so the commit went
// out unattributed and the trailing command died on an unknown switch.
describe("chained commit: notice attaches to the commit, not the chain", () => {
    const chained: Array<[string, string, string]> = [
        // [label, command, text expected immediately after the inserted notice]
        ["&& follows", `git commit -m "x" && git log`, " && git log"],
        ["; follows", `git commit -m "x" ; echo done`, " ; echo done"],
        ["|| follows", `git commit -m "x" || true`, " || true"],
        ["newline follows", `git commit -m "x"\ngit push`, "\ngit push"],
        [
            "two commands follow",
            `git commit -m "x" && git log && git status --short`,
            " && git log && git status --short",
        ],
        ["leading cd, trailing status", `cd /tmp && git commit -m "y" && git status`, " && git status"],
    ]
    for (const [label, cmd, tail] of chained) {
        test(label, () => {
            const r = rewriteCommand(cmd)
            expect(r.action).toBe("change")
            if (r.action !== "change") return
            expect(r.cmd).toBe(cmd.slice(0, cmd.length - tail.length) + ` -m "${NOTICE}"` + tail)
        })
    }

    test("a separator inside the message does not split the segment", () => {
        const r = rewriteCommand(`git commit -m "fix a && b" && git log`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toBe(`git commit -m "fix a && b" -m "${NOTICE}" && git log`)
    })

    test("a separator inside $() does not split the segment", () => {
        const r = rewriteCommand(`git commit -m "$(echo a && echo b)" && git log`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toBe(`git commit -m "$(echo a && echo b)" -m "${NOTICE}" && git log`)
    })

    test("unterminated quoting → left untouched rather than corrupted", () => {
        expect(rewriteCommand(`git commit -m "x && git log`).action).toBe("none")
    })

    // A `&` that belongs to a redirection is not a segment separator. Splitting there
    // cut `2>&1` in half and spliced the flag between `2>` and `1`, which bash reads as
    // a redirect to a file named `-m`, backgrounds the commit, and passes the notice to
    // git as a pathspec instead of a message.
    test("redirection &  does not split the segment", () => {
        const r = rewriteCommand(`git commit -m "x" 2>&1 | tee log`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toBe(`git commit -m "x" 2>&1 -m "${NOTICE}" | tee log`)
    })

    // The -m presence check ran on the whole chain, so a stray -m on a LATER command
    // qualified an editor-driven commit — turning it non-interactive with the notice as
    // its entire message. --amend variants rewrote a real commit's message.
    test("editor commit with -m only on a later command → none", () => {
        expect(rewriteCommand(`git add -A && git commit && git log -1 -m`).action).toBe("none")
    })
    test("--amend --no-edit with -m only on a later command → none", () => {
        expect(rewriteCommand(`git commit --amend --no-edit && git show -m HEAD`).action).toBe("none")
    })

    // Heredoc bodies are data, not segments. The first `git commit` inside one used to
    // match, so the flag was written into the FILE. An unquoted heredoc anywhere in the
    // chain now bails: no attribution, but nothing corrupted.
    test("git commit inside a heredoc body is never rewritten", () => {
        const cmd = `cat <<EOF > notes.txt\ngit commit -m fake\nEOF\ngit commit -m real`
        expect(rewriteCommand(cmd).action).toBe("none")
    })
    test("a heredoc inside a quoted -m still attributes normally", () => {
        const cmd = `git commit -m "$(cat <<'EOF'\nbody\nEOF\n)"`
        const r = rewriteCommand(cmd)
        expect(r.action).toBe("change")
        if (r.action === "change") expect(r.cmd).toBe(`${cmd} -m "${NOTICE}"`)
    })

    test("unbalanced paren outside quotes → left untouched", () => {
        expect(rewriteCommand(`git commit -m \${p//(/-} && echo done`).action).toBe("none")
    })

    test("escaped trailing space is not walked back over", () => {
        const r = rewriteCommand(`git commit -m x\\ && echo done`)
        // the escaped space stays inside the message word; the notice follows as its own -m
        if (r.action === "change") expect(r.cmd).toBe(`git commit -m x\\  -m "${NOTICE}"&& echo done`)
    })

    // -F/--file denies scanned the whole chain, blocking any later command using -F.
    test("grep -F later in the chain does not deny the commit", () => {
        const r = rewriteCommand(`git commit -m "x" && grep -F foo file`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toBe(`git commit -m "x" -m "${NOTICE}" && grep -F foo file`)
    })

    test("combined short flags (-am, -sm) still get attributed", () => {
        for (const flag of ["-am", "-sm"]) {
            const r = rewriteCommand(`git commit ${flag} "x"`)
            expect(r.action).toBe("change")
            if (r.action === "change") expect(r.cmd).toBe(`git commit ${flag} "x" -m "${NOTICE}"`)
        }
    })

    test("git -C <dir> commit still gets attributed", () => {
        const r = rewriteCommand(`git -C /tmp commit -m "x" && echo done`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toBe(`git -C /tmp commit -m "x" -m "${NOTICE}" && echo done`)
    })

    test("unchained commit still appends at the end", () => {
        const r = rewriteCommand(`git commit -m "x"`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toBe(`git commit -m "x" -m "${NOTICE}"`)
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
    // Projects/milestones/documents replaced issues as the unit of work — each writes
    // its own prose field, so the map must cover them all or attribution silently lapses.
    const LINEAR_BODY_FIELDS: Array<[string, string]> = [
        ["save_project", "description"],
        ["save_milestone", "description"],
        ["save_initiative", "description"],
        ["save_document", "content"],
        ["save_status_update", "body"],
        ["save_release", "description"],
        ["save_release_note", "content"],
    ]
    for (const [tool, field] of LINEAR_BODY_FIELDS) {
        test(`claude Linear ${tool} attributes the ${field} field`, async () => {
            const r = await run(
                { tool: `mcp__claude_ai_Linear__${tool}`, toolInput: { [field]: "d" } },
                { directory: "." },
            )
            expect(r.kind).toBe("allow")
            if (r.kind === "allow") expect((r.updatedInput as any)[field]).toBe(`d\n\n${NOTICE}`)
        })
    }
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

// Regressions found by adversarial review of the segment-scoping change itself.
describe("segment scoping: checks must not read the whole chain", () => {
    test("quoted ' -m ' in --author does not qualify an editor-driven amend", () => {
        const cmd = `git commit --amend --no-edit --author="Foo -m Bar <x@y>"`
        expect(rewriteCommand(cmd).action).toBe("none")
    })
    test("an unquoted # comment bails rather than inserting into the comment", () => {
        expect(rewriteCommand(`git commit -m x # do it later\ngit push`).action).toBe("none")
    })
    test("a # inside the message is not a comment", () => {
        const r = rewriteCommand(`git commit -m "fix #123"`)
        expect(r.action).toBe("change")
        if (r.action === "change") expect(r.cmd).toBe(`git commit -m "fix #123" -m "${NOTICE}"`)
    })
    test("long run of dash flags matches in linear time, not exponential", () => {
        const cmd = "git " + "-a ".repeat(44) + "status"
        const t0 = performance.now()
        rewriteCommand(cmd)
        expect(performance.now() - t0).toBeLessThan(100)
    })
})

// The gh branch read the whole chain for its --body flag, so the FIRST -b anywhere
// won — including another command's. Verified in bash: the notice concatenated onto
// the branch name and the PR body shipped unattributed.
describe("gh: body flag is found on the gh segment only", () => {
    test("a preceding `git checkout -b` is not mistaken for the body flag", () => {
        const r = rewriteCommand(`git checkout -b "feat/x" && gh pr create --body "text"`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toBe(`git checkout -b "feat/x" && gh pr create --body "text""\n\n${NOTICE}"`)
        expect(r.cmd).toContain(`-b "feat/x" &&`) // branch name untouched
    })
    test("a preceding `curl -b` cookie is not mistaken for the body flag", () => {
        const r = rewriteCommand(`curl -b "session=abc" https://x && gh pr comment 1 --body "note"`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toContain(`curl -b "session=abc" https://x &&`)
        expect(r.cmd).toContain(`--body "note""\n\n${NOTICE}"`)
    })
    test("`--body` inside a quoted title does not swallow the real flag", () => {
        const r = rewriteCommand(`gh pr create --title "uses --body flag" --body "real"`)
        expect(r.action).toBe("change")
        if (r.action !== "change") return
        expect(r.cmd).toBe(`gh pr create --title "uses --body flag" --body "real""\n\n${NOTICE}"`)
    })
    test("a later `grep -F` no longer false-denies the gh post", () => {
        expect(rewriteCommand(`gh pr comment 1 --body "hi" && grep -F x file`).action).toBe("change")
    })
    test("a later `grep -F` no longer false-denies the commit", () => {
        expect(rewriteCommand(`git commit -m "fix" && grep -rn co-authored-by: .`).action).toBe("change")
    })
})
