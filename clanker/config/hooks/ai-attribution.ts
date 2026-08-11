import type { HookResult, HookCtx, HookInput } from "./hook-utils"

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
const FIELD_MAP: Record<string, string> = {
    mcp__claude_ai_Linear__save_comment: "body",
    mcp__claude_ai_Linear__save_issue: "description",
    "mcp__custom-tools__update_pr_info": "body",
    "mcp__custom-tools__resolve_pr_thread": "replyBody",
    "update-pr-info": "body",
    "resolve-pr-thread": "replyBody",
}

export function stripBranded(t: string): string {
    return t
        .replace(BRANDED_LINE, "")
        .replace(/\n{3,}/g, "\n\n")
        .replace(/\s+$/, "")
}

export function ensureNotice(t: string): string {
    const s = stripBranded(t || "")
    if (NOTICE_PRESENT.test(s)) return s // already attributed (bare or with model) — don't double
    return s ? s + "\n\n" + NOTICE : NOTICE
}

const reEsc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

// End of the shell WORD whose value begins at `start` (must be a quote), following
// shell quoting/escaping and adjacent-segment concatenation ('a'\''b', "a"'b', a\ b).
// Returns the index just past the word, or -1 if a quote is left unterminated
// (fail-safe: caller then leaves the command untouched rather than corrupt it).
export function bodyWordEnd(cmd: string, start: number): number {
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
                else if (cmd[i] === '"') { i++; closed = true; break }
                else i++
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

// Structure-only view for DETECTION: drop heredoc bodies + quoted strings so
// `git commit` / `gh pr …` appearing as data (a message, heredoc, or another
// command's args) isn't mistaken for the real command being invoked.
export function commandView(cmd: string): string {
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

export function rewriteCommand(cmd: string): Rewrite {
    if (cmd.includes(NOTICE)) return { action: "none" }
    const view = commandView(cmd)
    const isCommit = /(?:^|[\n;&|(`])\s*git\s+commit\b/.test(view)
    const isGhPost = /(?:^|[\n;&|(`])\s*gh\s+pr\s+(?:create|comment|edit)\b/.test(view)
    if (!isCommit && !isGhPost) return { action: "none" }
    if (CMD_BRANDED.test(view)) return { action: "deny" } // scan structural view — prose mentioning it isn't a trailer

    if (isCommit) {
        // scan `view` (not raw) so -F/--file in a message don't false-deny; bare -C dropped
        // (collides with git's global `-C <dir>` flag; --reuse-message covers it).
        if (/(?:^|\s)(?:-F|--file|--reuse-message|--reedit-message)\b/.test(view)) return { action: "deny" }
        if (!/(?:^|\s)(?:-m|--message)\b/.test(cmd)) return { action: "none" }
        return { action: "change", cmd: cmd.replace(/\s+$/, "") + ` -m "${NOTICE}"` }
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

export async function run(input: HookInput, _ctx: HookCtx): Promise<HookResult> {
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
