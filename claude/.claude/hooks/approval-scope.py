#!/usr/bin/env python3
"""UserPromptSubmit hook: when the user replies with a BARE approval, remind me
to confirm scope before executing — so a reflexive "yes" doesn't rubber-stamp a
bundled or consequential set of actions.

The fix is mostly on my side (don't bundle asks), but a bare approval still slips
through; this injects a slow-down reminder. Affirmation list calibrated from the
Conversations archive (yes/ye/proceed/sure/yeah/sounds good/go/do it/y/yup/ok…).

FAIL-OPEN, NON-BLOCKING: any error → no output → prompt proceeds unchanged.
"""
import sys
import json
import re

# Whole-message bare approvals (short, opens with an affirmation).
AFFIRM = re.compile(
    r"^(y|ye|yes|yep|yup|yeah|ya|sure|ok|okay|k|proceed|go|go ahead|do it|"
    r"sounds good|lgtm|ship it|please|yes please|go for it|👍)\b",
    re.I,
)

REMINDER = (
    "Bare approval detected. Before executing: confirm this 'yes' wasn't a bundled "
    "or consequential set. If my previous turn asked for more than one thing, or "
    "included an irreversible/outward-facing action (commit, push, delete, send, "
    "publish), restate exactly what this approves and confirm the rest per-item — "
    "don't run the whole batch on one yes."
)


def emit(text):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": text,
    }}, sys.stdout)


def main():
    data = json.load(sys.stdin)
    prompt = data.get("prompt")
    if not isinstance(prompt, str):
        return
    clean = "\n".join(l for l in prompt.splitlines() if not l.strip().startswith(">")).strip()
    if not clean or len(clean.split()) > 6:
        return
    if AFFIRM.match(clean):
        emit(REMINDER)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open
