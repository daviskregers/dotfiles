#!/usr/bin/env python3
"""PreToolUse hook (Write|Edit): soft TDD nudge.

When editing a source file (recognized code extension, not a test) inside a git
repo where NO test file is currently modified/staged, injects a reminder to
follow the red-green-refactor protocol and load the `tdd` skill. This is the
"partial" bucket: the invariant "source touched without test activity" is
checkable; "the test failed for the right reason" is not — so this NUDGES,
never blocks.

FAIL-OPEN: any error → no output → tool runs unchanged.
"""
import sys
import json
import os
import re
import subprocess

SRC_EXT = {
    ".py", ".js", ".jsx", ".ts", ".tsx", ".vue", ".go", ".rb", ".php", ".rs",
    ".java", ".kt", ".swift", ".c", ".cc", ".cpp", ".h", ".hpp", ".cs",
    ".scala", ".ex", ".exs", ".m", ".mm", ".lua",
}
TEST_RE = re.compile(r"(^|[/_.\-])(tests?|specs?|__tests__)([/_.\-]|$)", re.I)

REMINDER = (
    "TDD is default (global rule): before changing this source, there should be "
    "a failing test that exercises the new/changed behavior — no test file is "
    "currently modified in this repo. Red-green-refactor + rollback + contract-"
    "migration mechanics live in the `tdd` skill; load it before proceeding, or "
    "confirm this change is genuinely exempt (pure rename, generated code, config)."
)


def is_test_path(p):
    # match test/spec as path SEGMENTS, not substrings — so latest.py / inspector.py
    # aren't mistaken for tests.
    return TEST_RE.search(p) is not None


def repo_root(path):
    d = path if os.path.isdir(path) else os.path.dirname(path) or "."
    r = subprocess.run(
        ["git", "-C", d, "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, timeout=5,
    )
    return r.stdout.strip() if r.returncode == 0 else None


def has_modified_tests(root):
    r = subprocess.run(
        ["git", "-C", root, "status", "--porcelain"],
        capture_output=True, text=True, timeout=5,
    )
    if r.returncode != 0:
        return True  # can't tell → assume yes, stay quiet (fail-open)
    for line in r.stdout.splitlines():
        path = line[3:].strip()  # strip XY status prefix
        if path and is_test_path(path):
            return True
    return False


def emit_context(text):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": text,
    }}, sys.stdout)


def main():
    data = json.load(sys.stdin)
    ti = data.get("tool_input") or {}
    path = ti.get("file_path")
    if not isinstance(path, str) or not path:
        return
    _, ext = os.path.splitext(path)
    if ext.lower() not in SRC_EXT:
        return
    if is_test_path(path):
        return
    root = repo_root(path)
    if not root:
        return  # not a git repo (e.g. scratch vault) → no nudge
    if has_modified_tests(root):
        return
    emit_context(REMINDER)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open: never affect the tool on a hook bug
