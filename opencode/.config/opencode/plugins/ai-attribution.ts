import {
    extractOpencodeBefore,
    applyOpencodeBefore,
    type HookResult,
    type HookCtx,
    type HookInput,
} from "../hook-lib/hook-utils"

import { readFileSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { isAbsolute, join } from "node:path"

// Enforce AI attribution on commits + externally-posted content (EU AI Act Art. 50
// transparency). Appends `🤖 Generated with AI` to structured tool bodies and to
// git commit -m / gh pr create|comment|edit|review --body; a gh --body-file is
// attributed in the file itself. Strips tool-branded forms (Co-Authored-By,
// "Generated with Claude Code/opencode"). Denies only when the body is unreachable
// (commit message file, heredoc, a body-file path we can't resolve) or carries an
// unstrippable brand. allow → target mutates the tool args; deny → blocks.
// FAIL-OPEN on any bug.

const NOTICE = "🤖 Generated with AI"

// Branded attribution lines stripped from bodies.
const BRANDED_LINE = /^[ \t>]*(?:co-authored-by:.*|.*generated with (?:claude code|opencode).*)\s*$/gim
// Branded text in the posting command. Matched against that command's masked view,
// so the same words inside a quoted message are prose, not a trailer.
const CMD_BRANDED = /co-authored-by:|generated with (?:claude code|opencode)/i
// The two commands that post content, each anchored at the START of a segment.
// A flag's optional VALUE must not itself start with `-`, or `-a -b -c …` can be
// carved up two ways per token and the match goes exponential (a 44-token run took
// ~9s, hanging the tool call).
const SEG_IS_COMMIT = /^\s*(?:\w+=\S*\s+)*git\s+(?:-\S+\s+(?:[^-\s]\S*\s+)?)*commit\b/
const SEG_IS_GH = /^\s*gh\s+pr\s+(?:create|comment|edit|review)\b/
// A notice line already present, in either the bare or "(model)" form.
const NOTICE_PRESENT = new RegExp(`^[ \\t>]*${NOTICE}\\b`, "im")
// The --body / -b flag TOKEN only; the separator is a lookahead so nothing past the
// flag name is consumed. It is matched against the mask, where the body itself is
// blank — a `\s+` here would run the whole length of the blanked body and put the
// value offset past it. The value is then scanned with bodyWordEnd rather than a
// quoted-string regex: a naive regex closes at the first inner quote and would splice
// the notice into the MIDDLE of any body containing one (an escaped '\'' apostrophe
// in a single-quoted body, an unescaped " in a double-quoted one).
const BODY_FLAG_RE = /(?:^|\s)(?:--body|-b)(?==|\s)/
// The file-valued body flag. Matched on the mask like BODY_FLAG_RE, and deliberately
// separate from it: BODY_FLAG_RE's lookahead refuses `--body-file` so it can never
// consume a path as if it were prose.
const FILE_FLAG_RE = /(?:^|\s)(?:--body-file|-F)(?==|\s)/

// Structured tool name → field holding the postable body. Merged across targets:
// claude MCP names + opencode names. Names never collide, so each target matches
// only its own — the other keys are inert. (opencode has no Linear tool wired, so
// its Linear coverage matches the pre-existing plugin: none.)
//
// Every Linear entity that carries authored prose is listed — issues are no longer
// the only unit of work. Only the long-form field is attributed, never `summary`
// (255-char blurb shown in list views, where the notice would be pure noise).
// GAP: these tools also accept `patch` in place of the prose field; a patch-only
// update carries no body to attribute and passes through untouched.
const FIELD_MAP: Record<string, string> = {
    mcp__claude_ai_Linear__save_comment: "body",
    mcp__claude_ai_Linear__save_issue: "description",
    mcp__claude_ai_Linear__save_project: "description",
    mcp__claude_ai_Linear__save_milestone: "description",
    mcp__claude_ai_Linear__save_initiative: "description",
    mcp__claude_ai_Linear__save_document: "content",
    mcp__claude_ai_Linear__save_status_update: "body",
    mcp__claude_ai_Linear__save_release: "description",
    mcp__claude_ai_Linear__save_release_note: "content",
    "mcp__custom-tools__update_pr_info": "body",
    "mcp__custom-tools__resolve_pr_thread": "replyBody",
    "update-pr-info": "body",
    "resolve-pr-thread": "replyBody",
}

function stripBranded(t: string): string {
    return t
        .replace(BRANDED_LINE, "")
        .replace(/\n{3,}/g, "\n\n")
        .replace(/\s+$/, "")
}

function ensureNotice(t: string): string {
    const s = stripBranded(t || "")
    if (NOTICE_PRESENT.test(s)) return s // already attributed (bare or with model) — don't double
    return s ? s + "\n\n" + NOTICE : NOTICE
}

// End of the shell WORD whose value begins at `start` (must be a quote), following
// shell quoting/escaping and adjacent-segment concatenation ('a'\''b', "a"'b', a\ b).
// Returns the index just past the word, or -1 if a quote is left unterminated
// (fail-safe: caller then leaves the command untouched rather than corrupt it).
function bodyWordEnd(cmd: string, start: number): number {
    const n = cmd.length
    let i = start
    while (i < n) {
        const c = cmd[i]
        if (c === "'") {
            const close = cmd.indexOf("'", i + 1) // single quotes: literal to next '
            if (close < 0) return -1
            i = close + 1
        } else if (c === '"') {
            i++ // double quotes: honor \" escapes
            let closed = false
            while (i < n) {
                if (cmd[i] === "\\") i += 2
                else if (cmd[i] === '"') {
                    i++
                    closed = true
                    break
                } else i++
            }
            if (!closed) return -1
        } else if (c === "\\") {
            i += 2 // unquoted escaped char (incl. an escaped space) — part of the word
        } else if (/\s/.test(c) || ";|&<>()`".includes(c)) {
            break // unquoted boundary: word ends here
        } else {
            i++ // bare word char — concatenation glue between quoted segments
        }
    }
    return i
}

// The literal string a shell would pass for the WORD `w`, following the same quoting
// rules as bodyWordEnd. Returns null when the value cannot be known statically — an
// expansion (`$TMP/pr.md`, `$(mktemp)`) or unterminated quoting. The caller denies
// rather than guessing, because attributing the wrong file writes into an unrelated
// one and still posts the real body unattributed.
function unquoteWord(w: string): string | null {
    let out = ""
    let i = 0
    while (i < w.length) {
        const c = w[i]
        if (c === "'") {
            const close = w.indexOf("'", i + 1)
            if (close < 0) return null
            out += w.slice(i + 1, close)
            i = close + 1
        } else if (c === '"') {
            i++
            let closed = false
            while (i < w.length) {
                if (w[i] === "\\") {
                    out += w[i + 1] ?? ""
                    i += 2
                } else if (w[i] === '"') {
                    i++
                    closed = true
                    break
                } else if (w[i] === "$" || w[i] === "`") return null
                else out += w[i++]
            }
            if (!closed) return null
        } else if (c === "\\") {
            out += w[i + 1] ?? ""
            i += 2
        } else if (c === "$" || c === "`") {
            return null
        } else out += w[i++]
    }
    return out
}

type Scan = { segments: Array<{ start: number; end: number }>; mask: string }

// One structural pass over a command line, producing both things every caller needs:
//   segments — top-level spans, split on UNQUOTED separators (; && || | & newline)
//   mask     — the command with quoted spans blanked to spaces, SAME LENGTH, so a
//              regex match index maps 1:1 back onto the raw command
// Quoting/escaping follows the same rules as bodyWordEnd; `(`/`)` nest so a separator
// inside $(…) doesn't split. Returns null whenever the shape can't be read safely —
// unterminated quoting, unbalanced parens, an unquoted heredoc or comment — and every
// caller then leaves the command untouched rather than guessing.
function scanCommand(cmd: string): Scan | null {
    const n = cmd.length
    const m = cmd.split("")
    const blank = (a: number, b: number) => {
        for (let k = a; k < b; k++) m[k] = " "
    }
    const segments: Array<{ start: number; end: number }> = []
    let start = 0
    let i = 0
    let depth = 0
    while (i < n) {
        const c = cmd[i]
        if (c === "<" && cmd[i + 1] === "<" && cmd[i + 2] !== "<") {
            return null // unquoted heredoc: the body is data, and splitting inside it wrote the flag into a FILE
        } else if (c === "#" && (i === 0 || /\s/.test(cmd[i - 1]))) {
            return null // a comment swallows the rest of the line — the flag would land inside it, silently dropped
        } else if (c === "'" || c === "`") {
            const close = cmd.indexOf(c, i + 1) // literal to the matching mark
            if (close < 0) return null
            blank(i, close + 1)
            i = close + 1
        } else if (c === '"') {
            const open = i
            i++
            let closed = false
            while (i < n) {
                if (cmd[i] === "\\") i += 2
                else if (cmd[i] === '"') {
                    i++
                    closed = true
                    break
                } else i++
            }
            if (!closed) return null
            blank(open, i)
        } else if (c === "\\") {
            i += 2
        } else if (c === "(") {
            depth++
            i++
        } else if (c === ")") {
            if (depth > 0) depth--
            i++
        } else if (depth === 0 && (c === ";" || c === "\n" || c === "|" || (c === "&" && !isRedirectAmp(cmd, i)))) {
            segments.push({ start, end: i })
            while (i < n && ";\n&|".includes(cmd[i])) i++ // consume the whole separator
            start = i
        } else i++
    }
    if (depth !== 0) return null // unbalanced parens — we misread the structure, don't guess
    segments.push({ start, end: n })
    return { segments, mask: m.join("") }
}

// True when the `&` at `i` belongs to a redirection (`2>&1`, `>&2`) rather than
// separating commands. Splitting there spliced the flag between `2>` and `1`, which
// bash reads as a redirect to a file literally named `-m`.
function isRedirectAmp(cmd: string, i: number): boolean {
    const prev = cmd[i - 1]
    return prev === ">" || prev === "<"
}

type Target = { start: number; end: number; kind: "commit" | "gh"; mask: string }

// The ONE segment in a chain that actually posts content. Every later check runs
// against this span alone: scanning the whole chain let a sibling command's flags
// qualify the commit, deny it, or receive the notice itself — `git checkout -b
// "feat/x" && gh pr create --body "text"` used to append the notice to the BRANCH
// NAME and leave the PR body unattributed.
function targetSegment(cmd: string): Target | null {
    const scan = scanCommand(cmd)
    if (!scan) return null
    for (const s of scan.segments) {
        const seg = scan.mask.slice(s.start, s.end)
        if (SEG_IS_COMMIT.test(seg)) return { ...s, kind: "commit", mask: scan.mask }
        if (SEG_IS_GH.test(seg)) return { ...s, kind: "gh", mask: scan.mask }
    }
    return null
}

// A plan, not an effect: rewriteCommand stays pure so every shape above is unit-
// testable. `attributeFile` is the one case the caller executes as IO — the notice
// goes into the file gh will read, and the command itself runs untouched.
type Rewrite =
    | { action: "none" }
    | { action: "deny"; reason: string }
    | { action: "change"; cmd: string }
    | { action: "attributeFile"; path: string }

// Start of the value belonging to a flag matched at `m` on the segment's masked view,
// as an index into the RAW command. Handles both `--flag=value` and `--flag value`.
function flagValueStart(cmd: string, t: Target, m: RegExpExecArray): number {
    let v = t.start + m.index + m[0].length
    if (cmd[v] === "=") return v + 1
    while (v < t.end && /\s/.test(cmd[v])) v++
    return v
}

function rewriteCommand(cmd: string): Rewrite {
    if (cmd.includes(NOTICE)) return { action: "none" }
    const t = targetSegment(cmd)
    if (!t) return { action: "none" }
    // Structural view of the POSTING command only. Quoted spans are blank here, so
    // flags and branded text appearing as DATA (inside a message, a title, a sibling
    // command's args) can neither qualify the rewrite nor trigger a deny.
    const view = t.mask.slice(t.start, t.end)
    if (CMD_BRANDED.test(view)) return { action: "deny", reason: DENY_MSG }

    if (t.kind === "commit") {
        // bare -C dropped (collides with git's global `-C <dir>`; --reuse-message covers it).
        if (/(?:^|\s)(?:-F|--file|--reuse-message|--reedit-message)\b/.test(view)) {
            return { action: "deny", reason: DENY_MSG }
        }
        // `-[a-z]*m` also catches the combined short forms (-am, -sm).
        if (!/(?:^|\s)(?:-[a-zA-Z]*m|--message)\b/.test(view)) return { action: "none" }
        let e = t.end
        while (e > t.start && /\s/.test(cmd[e - 1])) {
            let b = e - 1
            while (b > t.start && cmd[b - 1] === "\\") b--
            if ((e - 1 - b) % 2 === 1) break // backslash-escaped space — part of the word, not padding
            e-- // keep the separator's spacing intact
        }
        return { action: "change", cmd: cmd.slice(0, e) + ` -m "${NOTICE}"` + cmd.slice(e) }
    }

    // Heredoc bodies never reach here — scanCommand bails on them.
    // A file body is attributed in the FILE, since there is nothing on the command line
    // to append to. The path has to be resolvable from the command text alone.
    const ffm = FILE_FLAG_RE.exec(view)
    if (ffm) {
        const vs = flagValueStart(cmd, t, ffm)
        const ve = bodyWordEnd(cmd, vs)
        if (ve < 0 || ve > t.end || ve === vs) return { action: "deny", reason: DENY_PATH }
        const path = unquoteWord(cmd.slice(vs, ve))
        if (!path || path === "-") return { action: "deny", reason: DENY_PATH } // `-` is stdin
        return { action: "attributeFile", path }
    }
    const fm = BODY_FLAG_RE.exec(view)
    if (!fm) return { action: "none" }
    const valStart = flagValueStart(cmd, t, fm)
    const q = cmd[valStart]
    if (q !== '"' && q !== "'") return { action: "none" } // only quoted bodies are safely editable
    const end = bodyWordEnd(cmd, valStart)
    if (end < 0 || end > t.end) return { action: "none" } // unterminated, or ran past this command
    // Append the notice as a concatenated, real-newline double-quoted segment at the
    // very end of the body word (mirrors the extra `-m` used for commits). Never
    // touch the body's internals, so no quote inside it can misplace the notice.
    return { action: "change", cmd: cmd.slice(0, end) + `"\n\n${NOTICE}"` + cmd.slice(end) }
}

const DENY_MSG =
    `AI attribution required: re-issue with an inline message/body ending in "${NOTICE}", ` +
    `and drop any Co-Authored-By / "Generated with Claude Code/opencode" lines. ` +
    `(Hook cannot safely edit a commit-message file or a heredoc body.)`

const DENY_PATH =
    `AI attribution required: the body file's path must be a literal the hook can read — ` +
    `not a variable, a command substitution, or stdin ("-"). ` +
    `Write the body to a real path and pass that, or pass it inline with --body.`

// Write the notice into the body file gh is about to read. Idempotent (ensureNotice
// no-ops on an already-attributed body) and FAIL-OPEN: an unreadable or missing path
// is left alone — gh fails on its own, and a hook bug must never block a tool.
function attributeFile(path: string, dir: string): void {
    const abs = path.startsWith("~/") ? join(homedir(), path.slice(2)) : isAbsolute(path) ? path : join(dir, path)
    try {
        const text = readFileSync(abs, "utf-8")
        const next = ensureNotice(text)
        if (next !== text) writeFileSync(abs, next, "utf-8")
    } catch {}
}

async function run(input: HookInput, ctx: HookCtx): Promise<HookResult> {
    const tool = input.tool ?? ""
    const ti = (input.toolInput ?? {}) as Record<string, any>

    const field = FIELD_MAP[tool]
    if (field) {
        const body = ti[field]
        if (typeof body !== "string" || !body.trim()) return { kind: "none" }
        const nv = ensureNotice(body)
        return nv === body ? { kind: "none" } : { kind: "allow", updatedInput: { ...ti, [field]: nv } }
    }

    if (tool === "Bash" || tool === "bash") {
        const cmd = input.command
        if (typeof cmd !== "string") return { kind: "none" }
        const r = rewriteCommand(cmd)
        if (r.action === "change") return { kind: "allow", updatedInput: { ...ti, command: r.cmd } }
        if (r.action === "deny") return { kind: "deny", reason: r.reason }
        // The command is already correct — only the file it points at needs the notice.
        if (r.action === "attributeFile") attributeFile(r.path, input.cwd ?? ctx.directory)
    }
    return { kind: "none" }
}

export const aiAttribution = async ({ directory }: { directory: string }) => ({
    "tool.execute.before": async (input: any, output: any) =>
        applyOpencodeBefore(output, await run(extractOpencodeBefore(input, output), { directory })),
})
