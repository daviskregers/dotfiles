#!/usr/bin/env python3
"""PostToolUse hook (Bash): after a `git push`, if the branch has an open PR,
remind to refresh its title/body via the `pr-describer` agent.

Global rule: a push changes the diff, so an existing PR's description is stale.
This is the "partial" bucket — "a PR exists" is checkable (gh), "the description
is now stale" is the inference we nudge on. Reminder only, never blocks.

FAIL-OPEN: any error (no gh, no PR, not a repo) → no output.
"""
import sys
import json
import os
import re
import subprocess


def emit_context(text):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": text,
    }}, sys.stdout)


def main():
    data = json.load(sys.stdin)
    if data.get("tool_name") != "Bash":
        return
    cmd = (data.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str) or not re.search(r"\bgit\s+push\b", cmd):
        return
    cwd = data.get("cwd") or os.getcwd()
    r = subprocess.run(
        ["gh", "pr", "view", "--json", "url,number"],
        capture_output=True, text=True, timeout=15, cwd=cwd,
    )
    if r.returncode != 0:
        return  # no PR for this branch, or gh unavailable
    try:
        pr = json.loads(r.stdout)
        url = pr.get("url")
    except Exception:
        return
    if not url:
        return
    emit_context(
        f"Push landed and this branch has an open PR ({url}). Its diff changed, "
        f"so the description is now stale — delegate a refresh of the title/body "
        f"to the `pr-describer` agent (never edit the description inline)."
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open
