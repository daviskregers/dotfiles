// PreToolUse-equivalent: enforce AI attribution on commits + externally-posted content.
// Mirrors claude/.claude/hooks/ai-attribution.py. Mutates output.args in place;
// throws (blocks) only when a body is file/heredoc-based or carries a branded form.
// FAIL-OPEN: unexpected errors are swallowed so a plugin bug never blocks a tool.

const NOTICE = "🤖 Generated with AI"

// Branded attribution lines stripped from bodies.
const BRANDED_LINE = /^[ \t>]*(?:co-authored-by:.*|.*generated with (?:claude code|opencode).*)\s*$/gim
// Branded text anywhere in a single-line command.
const CMD_BRANDED = /co-authored-by:|generated with (?:claude code|opencode)/i
// A notice line already present, in either the bare or "(model)" form.
const NOTICE_PRESENT = new RegExp(`^[ \\t>]*${NOTICE}\\b`, "im")
// --body "..." / -b '...' value capture.
const BODY_RE = /(--body|-b)(\s+|=)("(?:[^"\\]|\\.)*"|'[^']*')/

// opencode tool name -> field holding the postable body.
const FIELD_MAP = {
  "update-pr-info": "body",
  "resolve-pr-thread": "replyBody",
}

function stripBranded(t) {
  return t.replace(BRANDED_LINE, "").replace(/\n{3,}/g, "\n\n").replace(/\s+$/, "")
}

function ensureNotice(t) {
  const s = stripBranded(t || "")
  if (NOTICE_PRESENT.test(s)) return s  // already attributed (bare or with model) — don't double
  return s ? s + "\n\n" + NOTICE : NOTICE
}

function rewriteCommand(cmd) {
  if (cmd.includes(NOTICE)) return { action: "none" }
  const isCommit = /\bgit\s+commit\b/.test(cmd)
  const isGhPost = /\bgh\s+pr\s+(?:create|comment|edit)\b/.test(cmd)
  if (!isCommit && !isGhPost) return { action: "none" }
  if (CMD_BRANDED.test(cmd)) return { action: "deny" }

  if (isCommit) {
    if (/(?:^|\s)(?:-F|--file|-C|--reuse-message|--reedit-message)\b/.test(cmd)) return { action: "deny" }
    if (!/(?:^|\s)(?:-m|--message)\b/.test(cmd)) return { action: "none" }
    return { action: "change", cmd: cmd.replace(/\s+$/, "") + ` -m "${NOTICE}"` }
  }

  if (/--body-file|(?:^|\s)-F\b|<</.test(cmd)) return { action: "deny" }
  const m = BODY_RE.exec(cmd)
  if (!m) return { action: "none" }
  const raw = m[3]
  const quote = raw[0]
  const inner = raw.slice(1, -1)
  const newInner = quote === '"' ? ensureNotice(inner.replace(/\\n/g, "\n")) : ensureNotice(inner)
  const repl = `${m[1]}${m[2]}${quote}${newInner}${quote}`
  return { action: "change", cmd: cmd.slice(0, m.index) + repl + cmd.slice(m.index + m[0].length) }
}

const DENY_MSG =
  `AI attribution required: re-issue with an inline message/body ending in "${NOTICE}", ` +
  `and drop any Co-Authored-By / "Generated with Claude Code/opencode" lines. ` +
  `(Hook cannot safely edit file-based or heredoc bodies.)`

export const AiAttribution = async () => ({
  "tool.execute.before": async (input, output) => {
    try {
      const tool = input.tool
      const args = output.args
      if (FIELD_MAP[tool]) {
        const f = FIELD_MAP[tool]
        const body = args[f]
        if (typeof body === "string" && body.trim()) {
          const nv = ensureNotice(body)
          if (nv !== body) args[f] = nv
        }
        return
      }
      if (tool === "bash" && typeof args.command === "string") {
        const r = rewriteCommand(args.command)
        if (r.action === "change") args.command = r.cmd
        else if (r.action === "deny") throw new Error(DENY_MSG)
      }
    } catch (e) {
      if (e && typeof e.message === "string" && e.message.startsWith("AI attribution required")) throw e
      // fail-open on unexpected bugs
    }
  },
})
