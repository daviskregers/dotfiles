#!/usr/bin/env python3
"""PreToolUse hook: enforce AI attribution on commits + externally-posted content.

Auto-appends `🤖 Generated with AI` (via updatedInput) to:
  - structured tool fields (Linear save_comment/save_issue, custom-tools update_pr_info)
  - `git commit -m`, `gh pr create|comment|edit --body` (Bash)
Strips tool-branded forms (Co-Authored-By, "Generated with Claude Code/opencode").
Denies only when the body is file/heredoc-based (can't safely edit) or carries a
branded form it can't strip from the command string.

FAIL-OPEN: any error → no output → tool runs unchanged. Never block on a bug.
"""
import sys
import json
import re

NOTICE = "🤖 Generated with AI"

# A notice line already present, in either the bare or "(model)" form.
NOTICE_PRESENT = re.compile(r'(?im)^[ \t>]*' + re.escape(NOTICE) + r'\b')

# Lines that are tool-branded attribution — stripped from bodies, denied in commands.
BRANDED = re.compile(
    r'(?im)^[ \t>]*(?:co-authored-by:.*|.*generated with (?:claude code|opencode).*)\s*$'
)

# Structured tool name -> field holding the postable body.
FIELD_MAP = {
    "mcp__claude_ai_Linear__save_comment": "body",
    "mcp__claude_ai_Linear__save_issue": "description",
    "mcp__custom-tools__update_pr_info": "body",
    "mcp__custom-tools__resolve_pr_thread": "replyBody",
}

# Branded attribution anywhere in a command string (commands are single-line,
# so the line-anchored BRANDED regex above misses it inside -m "...").
CMD_BRANDED = re.compile(r'(?i)co-authored-by:|generated with (?:claude code|opencode)')

# --body "..." / -b '...' value capture (handles escaped dquotes).
BODY_RE = re.compile(r'(--body|-b)(\s+|=)("(?:[^"\\]|\\.)*"|\'[^\']*\')')


def strip_branded(text):
    return re.sub(r'\n{3,}', '\n\n', BRANDED.sub('', text)).rstrip()


def ensure_notice(text):
    t = strip_branded(text or "")
    if NOTICE_PRESENT.search(t):
        return t  # already attributed (bare or with model name) — don't double
    return (t + "\n\n" + NOTICE) if t else NOTICE


def emit_allow(updated_input):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "updatedInput": updated_input,
    }}, sys.stdout)


def emit_deny(reason):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}, sys.stdout)


def command_view(cmd):
    """Structure-only view for DETECTION: drop heredoc bodies and quoted strings
    so `git commit` / `gh pr …` appearing as data (a commit message, a heredoc, or
    another command's args) isn't mistaken for the real command being invoked."""
    s = cmd
    while True:
        m = re.search(r"<<-?\s*(['\"]?)([A-Za-z_]\w*)\1", s)
        if not m:
            break
        tag = re.escape(m.group(2))
        pat = re.compile(re.escape(m.group(0)) + r".*?^\s*" + tag + r"\s*$", re.S | re.M)
        new = pat.sub(" ", s, count=1)
        if new == s:  # no terminator found → drop from the heredoc operator to end
            new = s[:m.start()] + " "
        s = new
    s = re.sub(r"'[^']*'", " ", s)
    s = re.sub(r'"(?:[^"\\]|\\.)*"', " ", s)
    return s


def rewrite_command(cmd):
    """Return (new_cmd, action) where action in {'change','none','deny'}."""
    if NOTICE in cmd:
        return cmd, 'none'
    view = command_view(cmd)
    is_commit = re.search(r"(?:^|[\n;&|(`])\s*git\s+commit\b", view) is not None
    is_gh_post = re.search(r"(?:^|[\n;&|(`])\s*gh\s+pr\s+(?:create|comment|edit)\b", view) is not None
    if not (is_commit or is_gh_post):
        return cmd, 'none'
    if CMD_BRANDED.search(view):  # scan the structural view — a message that MENTIONS
        return cmd, 'deny'         # "Co-Authored-By" in prose isn't a branded trailer

    if is_commit:
        # File/reuse-message commits can't take an extra -m safely. Scan `view` (not raw)
        # so "-F"/"--file" appearing inside a commit message don't false-deny. Bare "-C"
        # dropped — it collides with git's global `-C <dir>` flag; --reuse-message covers it.
        if re.search(r'(?:^|\s)(?:-F|--file|--reuse-message|--reedit-message)\b', view):
            return cmd, 'deny'
        # No inline message → editor-driven; nothing to inject.
        if not re.search(r'(?:^|\s)(?:-m|--message)\b', cmd):
            return cmd, 'none'
        return cmd.rstrip() + f' -m "{NOTICE}"', 'change'

    # gh pr create|comment|edit
    if re.search(r'--body-file|(?:^|\s)-F\b|<<', view):
        return cmd, 'deny'
    m = BODY_RE.search(cmd)
    if not m:
        return cmd, 'none'  # no inline body set (e.g. --add-reviewer)
    raw = m.group(3)
    quote = raw[0]
    inner = raw[1:-1]
    if quote == '"':
        new_inner = ensure_notice(inner.replace('\\n', '\n'))
    else:
        new_inner = ensure_notice(inner)
    repl = f'{m.group(1)}{m.group(2)}{quote}{new_inner}{quote}'
    return cmd[:m.start()] + repl + cmd[m.end():], 'change'


def main():
    data = json.load(sys.stdin)
    tool = data.get("tool_name", "")
    ti = data.get("tool_input") or {}

    if tool in FIELD_MAP:
        field = FIELD_MAP[tool]
        body = ti.get(field)
        if not isinstance(body, str) or not body.strip():
            return
        new_val = ensure_notice(body)
        if new_val == body:
            return
        upd = dict(ti)
        upd[field] = new_val
        emit_allow(upd)
        return

    if tool == "Bash":
        cmd = ti.get("command")
        if not isinstance(cmd, str):
            return
        new_cmd, action = rewrite_command(cmd)
        if action == 'change':
            upd = dict(ti)
            upd["command"] = new_cmd
            emit_allow(upd)
        elif action == 'deny':
            emit_deny(
                f'AI attribution required. Re-issue with an inline message/body ending in '
                f'"{NOTICE}", and drop any Co-Authored-By / "Generated with Claude Code/opencode" '
                f'lines. (Hook cannot safely edit file-based or heredoc bodies.)'
            )
        return


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open: never block the tool on a hook bug
