#!/usr/bin/env python3
"""PreToolUse hook (Bash): hard-block catastrophic / irreversible commands so a
reflexive permission-approval can't run them. Best-effort, NOT a sandbox.

Scans two views and denies if EITHER fires:
  1. the command with message-flag values (-m/--message/--body) stripped — so a
     commit/PR message that merely MENTIONS a dangerous string doesn't false-fire;
  2. the contents of every command substitution ($(...), `...`, ${...}) — those
     execute regardless of which quote/flag they sit in, so they're always scanned.

FAIL-OPEN: any error → no output → command runs (subject to normal permissions).
"""
import sys
import json
import re

# git/gh global options tolerated before the subcommand (git -C path, -c k=v, --long).
GITX = r"(?:-C\s+\S+\s+|-c\s+\S+\s+|--\S+\s+|-\w+\s+)*"

DANGER = [
    (rf"\bgit\s+{GITX}push\b[^|;&\n]*(?:--force(?!-with-lease\b|-if-includes\b)|\s-f\b)", "git force-push"),
    (rf"\bgit\s+{GITX}reset\s+--hard\b", "git reset --hard (discards work)"),
    (rf"\bgit\s+{GITX}clean\s+-\S*f", "git clean -f (deletes untracked)"),
    (r"\b(?:migrate:fresh|migrate:reset|db:wipe)\b", "destructive DB migration (drops all tables)"),
    (r"\b(?:rails\s+db:drop|prisma\s+migrate\s+reset|sequelize\s+db:drop)\b", "destructive DB reset"),
    (r"\bDROP\s+(?:TABLE|DATABASE|SCHEMA)\b|\bTRUNCATE\s+(?:TABLE\s+)?\w", "destructive SQL (DROP/TRUNCATE)"),
    (r"\bdd\b[^|;&\n]*\bof=", "dd (raw disk/file overwrite)"),
    (r"\bmkfs\b|>\s*/dev/(?:sd|nvme|disk)|\bof=/dev/", "write to block device / format"),
    (r"\bfind\b[^|;&\n]*(?:-delete\b|-exec\s+rm\b)", "find with -delete / -exec rm"),
    (r"(?:curl|wget)\b[^|\n]*\|\s*(?:sudo\s+)?(?:sh|bash|zsh)\b", "pipe remote script into a shell"),
    (r"\bterraform\s+destroy\b", "terraform destroy"),
    (r"\bdocker\s+system\s+prune\b|\bdocker\s+volume\s+rm\b", "docker destructive prune / volume rm"),
    (r"(?:^|[\s;&|(\\`])(?:\S*/)?aws(?=\s|$)", "the AWS CLI — disallowed for the agent (run it yourself if needed)"),
    (r":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:", "fork bomb"),
]
DANGER = [(re.compile(p, re.I), label) for p, label in DANGER]

MSG_FLAG = re.compile(r"(?:-m|--message|--body)(?:=|\s+)(?:\"(?:[^\"\\]|\\.)*\"|'[^']*'|\S+)")
SUBST = re.compile(r"\$\(([^)]*)\)|`([^`]*)`|\$\{([^}]*)\}")


def strip_message_flags(cmd):
    # values of message flags are prose, not commands — remove so a mention
    # doesn't false-fire. (Live substitutions inside them are scanned separately.)
    return MSG_FLAG.sub(" ", cmd)


def substitutions(cmd):
    return " ".join(g for m in SUBST.finditer(cmd) for g in m.groups() if g)


def rm_recursive_force(text):
    """Token-based: an `rm` invocation whose flags include BOTH recursive and
    force, in any order, tolerant of intervening flags and long options."""
    toks = text.split()
    for i, t in enumerate(toks):
        if t.split("/")[-1] != "rm":
            continue
        if i > 0 and toks[i - 1].split("/")[-1] == "git":
            continue  # `git rm` is the index remove (recoverable) — not this guard's target
        short, longs = "", []
        for t2 in toks[i + 1:]:
            if t2.startswith("--"):
                longs.append(t2)
            elif t2.startswith("-") and len(t2) > 1:
                short += t2[1:]
            else:
                break
        has_r = "r" in short.lower() or "--recursive" in longs
        has_f = "f" in short.lower() or "--force" in longs
        if has_r and has_f:
            return True
    return False


def chmod_777_recursive(text):
    toks = text.split()
    for i, t in enumerate(toks):
        if t.split("/")[-1] != "chmod":
            continue
        rest = [x for x in toks[i + 1:]]
        recursive = any(x == "--recursive" or (x.startswith("-") and not x.startswith("--") and "R" in x) for x in rest)
        mode = any(x in ("777", "0777", "a+rwx") for x in rest)
        if recursive and mode:
            return True
    return False


def emit_deny(reason):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}, sys.stdout)


def scan(text):
    if rm_recursive_force(text):
        return "recursive force delete (rm -rf)"
    if chmod_777_recursive(text):
        return "chmod -R 777"
    for rx, label in DANGER:
        if rx.search(text):
            return label
    return None


def main():
    data = json.load(sys.stdin)
    if data.get("tool_name") != "Bash":
        return
    cmd = (data.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        return
    for text in (strip_message_flags(cmd), substitutions(cmd)):
        if not text.strip():
            continue
        label = scan(text)
        if label:
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
