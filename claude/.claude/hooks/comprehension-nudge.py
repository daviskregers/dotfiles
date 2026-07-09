#!/usr/bin/env python3
"""Stop hook: when a session produced a SUBSTANTIAL source change, block the
stop once to force an incremental comprehension checkpoint (active-recall) so a
spec-delegated build doesn't ship as a black box.

Guards against nagging:
  - `stop_hook_active`: skip if we already caused a continuation (loop guard).
  - diff-signature dedup: nudge at most once per distinct changed-source state
    per cwd (state file in ~/.claude/cache). Grows again only if the build grows.

Only trips above a HIGH threshold (real builds, not small edits). FAIL-OPEN:
any error → allow stop.
"""
import sys
import json
import os
import re
import hashlib
import subprocess

SRC_EXT = {
    ".py", ".js", ".jsx", ".ts", ".tsx", ".vue", ".go", ".rb", ".php", ".rs",
    ".java", ".kt", ".swift", ".c", ".cc", ".cpp", ".h", ".hpp", ".cs",
    ".scala", ".ex", ".exs", ".m", ".mm", ".lua",
}
IGNORE = re.compile(r"(lock|\.min\.|generated|/vendor/|/node_modules/|/dist/)", re.I)
MIN_LINES = 150
MIN_FILES = 5
STATE = os.path.expanduser("~/.claude/cache/comprehension-nudge.json")

REASON = (
    "This session changed a substantial amount of source. Before you stop, run an "
    "incremental comprehension checkpoint (shared-reasoning rule) so this doesn't "
    "ship as a black box: for each meaningful piece, what it does + how it fits + "
    "the one design decision that matters + the seam most likely to bite. Frame it "
    "as ACTIVE RECALL — ask me to predict what a piece does or where the risk is, "
    "don't lecture. Offer `/explain` or the `tutor` agent for the complex parts, and "
    "flag + offer `/simplify` if the design has become a ball of mud. If I already "
    "understand it, a one-line confirmation from me is enough."
)


def numstat(cwd, cached):
    args = ["git", "-C", cwd, "diff", "--numstat"] + (["--cached"] if cached else [])
    r = subprocess.run(args, capture_output=True, text=True, timeout=8)
    return r.stdout if r.returncode == 0 else ""


def changed_source(cwd):
    lines_total, files = 0, set()
    for cached in (False, True):
        for row in numstat(cwd, cached).splitlines():
            parts = row.split("\t")
            if len(parts) != 3:
                continue
            added, deleted, path = parts
            _, ext = os.path.splitext(path)
            if ext.lower() not in SRC_EXT or IGNORE.search(path):
                continue
            files.add(path)
            lines_total += (int(added) if added.isdigit() else 0) + (int(deleted) if deleted.isdigit() else 0)
    return lines_total, files


def signature(cwd, files, lines):
    bucket = lines // 100  # coarse; only re-nudge on material growth
    raw = cwd + "|" + "|".join(sorted(files)) + f"|{bucket}"
    return hashlib.sha1(raw.encode()).hexdigest()


def already_nudged(cwd, sig):
    try:
        with open(STATE) as f:
            state = json.load(f)
    except Exception:
        state = {}
    if state.get(cwd) == sig:
        return True
    state[cwd] = sig
    try:
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        with open(STATE, "w") as f:
            json.dump(state, f)
    except Exception:
        pass
    return False


def main():
    data = json.load(sys.stdin)
    if data.get("stop_hook_active"):
        return  # we already forced a continuation — don't loop
    cwd = data.get("cwd") or os.getcwd()
    lines, files = changed_source(cwd)
    if lines < MIN_LINES and len(files) < MIN_FILES:
        return  # not substantial
    sig = signature(cwd, files, lines)
    if already_nudged(cwd, sig):
        return  # same build state already nudged
    json.dump({"decision": "block", "reason": REASON}, sys.stdout)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open: allow stop
