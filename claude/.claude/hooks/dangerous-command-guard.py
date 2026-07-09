#!/usr/bin/env python3
"""PreToolUse hook (Bash): hard-block catastrophic / irreversible commands so a
reflexive permission-approval can't run them.

The problem: permission-prompt fatigue → commands approved without reading. This
moves the genuinely dangerous decision OFF the reflexive click: the command is
denied with a loud reason, and the user runs it deliberately via `!` if truly
intended. Best-effort pattern match, NOT a sandbox — it catches the classic
foot-guns, not every possible one.

FAIL-OPEN: any error → no output → command runs (subject to normal permissions).
"""
import sys
import json
import re

# (pattern, human label). Case-insensitive. Scoped to clearly destructive forms.
DANGER = [
    (r"\brm\s+(?:-\S+\s+)*-\S*r\S*f|\brm\s+(?:-\S+\s+)*-\S*f\S*r|\brm\s+-[rf]\s+-[rf]\b", "recursive force delete (rm -rf)"),
    (r"(?:^|\s|/)rm\s+-[a-z]*r[a-z]*\s+/(?:\s|$|\*)", "recursive delete from filesystem root"),
    (r"\bgit\s+push\b[^|;&\n]*(?:--force(?!-with-lease)\b|\s-f\b)", "git force-push"),
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard (discards work)"),
    (r"\bgit\s+clean\s+-\S*f", "git clean -f (deletes untracked)"),
    (r"\b(?:migrate:fresh|migrate:reset|db:wipe)\b", "destructive DB migration (drops all tables)"),
    (r"\b(?:rails\s+db:drop|prisma\s+migrate\s+reset|sequelize\s+db:drop)\b", "destructive DB reset"),
    (r"\bDROP\s+(?:TABLE|DATABASE|SCHEMA)\b|\bTRUNCATE\s+(?:TABLE\s+)?\w", "destructive SQL (DROP/TRUNCATE)"),
    (r"\bdd\b[^|;&\n]*\bof=", "dd (raw disk/file overwrite)"),
    (r"\bmkfs\b|>\s*/dev/(?:sd|nvme|disk)|\bof=/dev/", "write to block device / format"),
    (r"\bfind\b[^|;&\n]*(?:-delete\b|-exec\s+rm\b)", "find with -delete / -exec rm"),
    (r"(?:curl|wget)\b[^|\n]*\|\s*(?:sudo\s+)?(?:sh|bash|zsh)\b", "pipe remote script into a shell"),
    (r"\bchmod\s+-R\s+0?777\b", "chmod -R 777"),
    (r"\bterraform\s+destroy\b", "terraform destroy"),
    (r"\bdocker\s+system\s+prune\b|\bdocker\s+volume\s+rm\b", "docker destructive prune / volume rm"),
    (r"(?:^|[\s;&|(])aws\s+\S", "the AWS CLI — disallowed for the agent (run it yourself if needed)"),
    (r":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:", "fork bomb"),
]
DANGER = [(re.compile(p, re.I), label) for p, label in DANGER]


def emit_deny(reason):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}, sys.stdout)


# Values of human-message flags are prose, never a command — strip them before
# scanning so a commit message / PR body that merely MENTIONS a dangerous string
# ("… blocks rm -rf …") doesn't false-positive. Only -m/--message/--body; NOT -c
# or --body-file, so genuinely dangerous quoted payloads (psql -c 'DROP …') and
# real invocations stay scanned.
MSG_FLAG = re.compile(
    r"(?:-m|--message|--body)(?:=|\s+)(?:\"(?:[^\"\\]|\\.)*\"|'[^']*'|\S+)"
)


def strip_message_flags(cmd):
    return MSG_FLAG.sub(" ", cmd)


def main():
    data = json.load(sys.stdin)
    if data.get("tool_name") != "Bash":
        return
    cmd = (data.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        return
    scan = strip_message_flags(cmd)
    for rx, label in DANGER:
        if rx.search(scan):
            emit_deny(
                f"Blocked by the command guard — {label}. Denied so it can't run on a "
                f"reflexive approval. If you genuinely intend it, run it yourself via the "
                f"`!` prefix, or restate it explicitly and I'll explain exactly what it does first."
            )
            return


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open: never block on a hook bug
