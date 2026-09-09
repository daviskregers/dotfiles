import { extractClaudeInput, serializeClaudeResult, type HookResult, type HookCtx, type HookInput } from "./hook-utils"

// Enforce AI attribution on commits + externally-posted content (EU AI Act Art. 50
// transparency). Appends `🤖 Generated with AI` to structured tool bodies and to
// git commit -m / gh pr create|comment|edit --body; strips tool-branded forms
// (Co-Authored-By, "Generated with Claude Code/opencode"). Denies only when the
// body is file/heredoc-based (can't safely edit) or carries an unstrippable brand.
// allow → target mutates the tool args; deny → blocks. FAIL-OPEN on any bug.

const NOTICE = "🤖 Generated with AI"

// Branded attribution lines stripped from bodies.
const BRANDED_LINE = /^[ \t>]*(?:co-authored-by:.*|.*generated with (?:claude code|opencode).*)\s*$/gim
// Branded text anywhere in a single-line command.
const CMD_BRANDED = /co-authored-by:|generated with (?:claude code|opencode)/i
// A `git commit` invocation: optional VAR=value assignments, then git's own global
// flags (`git -C dir commit`). One source, two anchorings — whole-command detection
// needs a separator boundary, per-segment matching starts at the segment.
// CMD_IS_COMMIT is the LOOSER of the two: it also fires inside `(…)` and backticks,
// which splitSegments never splits on, so those detect as a commit and then find no
// segment — `none`, not an attribution.
// A flag's optional VALUE must not itself start with `-`, or `-a -b -c …` can be
// carved up two ways per token and the match goes exponential (a 44-token run took
// ~9s, hanging the tool call).
const GIT_COMMIT = String.raw`(?:\w+=\S*\s+)*git\s+(?:-\S+\s+(?:[^-\s]\S*\s+)?)*commit\b`
const CMD_IS_COMMIT = new RegExp(String.raw`(?:^|[\n;&|(\`])\s*` + GIT_COMMIT)
const SEG_IS_COMMIT = new RegExp(String.raw`^\s*` + GIT_COMMIT)
// A notice line already present, in either the bare or "(model)" form.
const NOTICE_PRESENT = new RegExp(`^[ \\t>]*${NOTICE}\\b`, "im")
// --body / -b flag (value follows). The value is scanned with bodyWordEnd rather
// than a quoted-string regex — a naive regex closes at the first inner quote and
// would splice the notice into the MIDDLE of any body containing a quote (an
// escaped '\'' apostrophe in a single-quoted body, an unescaped " in a
// double-quoted one). See bodyWordEnd.
const BODY_FLAG_RE = /(--body|-b)(\s+|=)/

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

const reEsc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

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

// Top-level segment spans of a command line, split on UNQUOTED separators
// (; && || | & newline). Quoting/escaping is followed as in bodyWordEnd, and
// `(`/`)` nest so a separator inside $(…) doesn't split. Returns null on
// unterminated quoting — the caller then leaves the command untouched.
//
// Needed because commandView is not index-preserving (it rewrites spans to a
// single space), so its offsets can't be mapped back onto the raw command.
function splitSegments(cmd: string): Array<{ start: number; end: number }> | null {
    const out: Array<{ start: number; end: number }> = []
    const n = cmd.length
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
            i = close + 1
        } else if (c === '"') {
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
        } else if (c === "\\") {
            i += 2
        } else if (c === "(") {
            depth++
            i++
        } else if (c === ")") {
            if (depth > 0) depth--
            i++
        } else if (depth === 0 && (c === ";" || c === "\n" || c === "|" || (c === "&" && !isRedirectAmp(cmd, i)))) {
            out.push({ start, end: i })
            while (i < n && ";\n&|".includes(cmd[i])) i++ // consume the whole separator
            start = i
        } else i++
    }
    if (depth !== 0) return null // unbalanced parens — we misread the structure, don't guess
    out.push({ start, end: n })
    return out
}

// True when the `&` at `i` belongs to a redirection (`2>&1`, `>&2`) rather than
// separating commands. Splitting there spliced the flag between `2>` and `1`, which
// bash reads as a redirect to a file literally named `-m`.
function isRedirectAmp(cmd: string, i: number): boolean {
    const prev = cmd[i - 1]
    return prev === ">" || prev === "<"
}

// Span of the `git commit` invocation inside a possibly-chained command. An
// unrecognised shape yields null → no attribution, rather than a flag appended to
// whatever command happens to come last.
function commitSegment(cmd: string): { start: number; end: number } | null {
    const segs = splitSegments(cmd)
    if (!segs) return null
    return segs.find((s) => SEG_IS_COMMIT.test(commandView(cmd.slice(s.start, s.end)))) ?? null
}

// Structure-only view for DETECTION: drop heredoc bodies + quoted strings so
// `git commit` / `gh pr …` appearing as data (a message, heredoc, or another
// command's args) isn't mistaken for the real command being invoked.
function commandView(cmd: string): string {
    let s = cmd
    for (;;) {
        const m = /<<-?\s*(['"]?)([A-Za-z_]\w*)\1/.exec(s)
        if (!m) break
        const pat = new RegExp(reEsc(m[0]) + "[\\s\\S]*?^\\s*" + reEsc(m[2]) + "\\s*$", "m")
        const next = s.replace(pat, " ")
        s = next === s ? s.slice(0, m.index) + " " : next // no terminator → drop to end
    }
    return s.replace(/'[^']*'/g, " ").replace(/"(?:[^"\\]|\\.)*"/g, " ")
}

type Rewrite = { action: "none" } | { action: "deny" } | { action: "change"; cmd: string }

function rewriteCommand(cmd: string): Rewrite {
    if (cmd.includes(NOTICE)) return { action: "none" }
    const view = commandView(cmd)
    const isCommit = CMD_IS_COMMIT.test(view)
    const isGhPost = /(?:^|[\n;&|(`])\s*gh\s+pr\s+(?:create|comment|edit)\b/.test(view)
    if (!isCommit && !isGhPost) return { action: "none" }
    if (CMD_BRANDED.test(view)) return { action: "deny" } // scan structural view — prose mentioning it isn't a trailer

    if (isCommit) {
        // Work on the commit's OWN segment, never the whole chain. Appending to the raw
        // string put the flag on the last command of a chain; and scanning the whole
        // chain for flags let a later command's `-m` qualify an editor-driven commit
        // (turning it non-interactive with the notice as its entire message) and a
        // later `grep -F` false-deny the commit.
        const seg = commitSegment(cmd)
        if (!seg) return { action: "none" }
        const segRaw = cmd.slice(seg.start, seg.end)
        // scan the segment's view (not raw) so -F/--file inside a message don't false-deny;
        // bare -C dropped (collides with git's global `-C <dir>`; --reuse-message covers it).
        const segView = commandView(segRaw)
        if (/(?:^|\s)(?:-F|--file|--reuse-message|--reedit-message)\b/.test(segView)) return { action: "deny" }
        // `-[a-z]*m` also catches the combined short forms (-am, -sm). Scan the VIEW:
        // on raw, a quoted arg containing " -m " (`--author="Foo -m Bar <x@y>"`)
        // qualifies an editor-driven --amend and overwrites its message with the notice.
        if (!/(?:^|\s)(?:-[a-zA-Z]*m|--message)\b/.test(segView)) return { action: "none" }
        let e = seg.end
        while (e > seg.start && /\s/.test(cmd[e - 1])) {
            let b = e - 1
            while (b > seg.start && cmd[b - 1] === "\\") b--
            if ((e - 1 - b) % 2 === 1) break // backslash-escaped space — part of the word, not padding
            e-- // keep the separator's spacing intact
        }
        return { action: "change", cmd: cmd.slice(0, e) + ` -m "${NOTICE}"` + cmd.slice(e) }
    }

    if (/--body-file|(?:^|\s)-F\b|<</.test(view)) return { action: "deny" }
    const fm = BODY_FLAG_RE.exec(cmd)
    if (!fm) return { action: "none" }
    const valStart = fm.index + fm[0].length
    const q = cmd[valStart]
    if (q !== '"' && q !== "'") return { action: "none" } // only quoted bodies are safely editable
    const end = bodyWordEnd(cmd, valStart)
    if (end < 0) return { action: "none" } // unterminated quoting — don't risk corrupting it
    // Append the notice as a concatenated, real-newline double-quoted segment at the
    // very end of the body word (mirrors the extra `-m` used for commits). Never
    // touch the body's internals, so no quote inside it can misplace the notice.
    const seg = `"\n\n${NOTICE}"`
    return { action: "change", cmd: cmd.slice(0, end) + seg + cmd.slice(end) }
}

const DENY_MSG =
    `AI attribution required: re-issue with an inline message/body ending in "${NOTICE}", ` +
    `and drop any Co-Authored-By / "Generated with Claude Code/opencode" lines. ` +
    `(Hook cannot safely edit file-based or heredoc bodies.)`

async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
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
        if (r.action === "deny") return { kind: "deny", reason: DENY_MSG }
    }
    return { kind: "none" }
}

async function main() {
    const data = JSON.parse(await Bun.stdin.text())
    const r = await run(extractClaudeInput("PreToolUse", data), { directory: process.env.PROJECT_DIR || process.cwd() })
    const out = serializeClaudeResult("PreToolUse", r)
    if (out) process.stdout.write(out)
}
main().catch(() => {})
