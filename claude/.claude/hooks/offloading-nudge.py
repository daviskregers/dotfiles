#!/usr/bin/env python3
"""UserPromptSubmit hook: nudge when a prompt looks like a bare problem dump.

Signal (heuristic, judgment bucket — mechanizes the *reminder*, not the
judgment): the prompt references an artifact (URL or error/log paste) but states
NO hypothesis, and is short enough to be a dump rather than a considered report.
Injects the shared-reasoning rule as salient context so the agent leads with
hypotheses + a discriminating check instead of a black-box fix.

FAIL-OPEN and NON-BLOCKING: any error → no output → prompt proceeds unchanged.
"""
import sys
import json
import re

URL = re.compile(r"https?://", re.I)
ERROR_MARKER = re.compile(r"\b(error|exception|traceback|stack ?trace|failed|failing|fatal|panic)\b", re.I)
# Markers that the user has already done some thinking / posed a question.
HYPOTHESIS = re.compile(
    r"(\?|\bi think\b|\bi suspect\b|\bi bet\b|\bbecause\b|\bhypothes|\brule[d]? out\b|"
    r"\bmaybe\b|\bcould be\b|\bmight be\b|\bmy guess\b|\bseems like\b|\bprobably\b|\bwhy\b)",
    re.I,
)

NUDGE = (
    "This prompt looks like a bare problem dump (artifact/link, no stated "
    "hypothesis). Per the shared-reasoning rule: if the diagnosis is non-trivial, "
    "open with your candidate hypotheses + the cheapest discriminating check and "
    "invite a prediction before handing back a fix — keep me in the loop. If it's "
    "genuinely trivial/mechanical, just do it."
)


def emit(text):
    json.dump({"hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": text,
    }}, sys.stdout)


def main():
    data = json.load(sys.stdin)
    prompt = data.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        return
    if len(prompt.split()) > 120:
        return  # long, considered report — don't nag
    if not (URL.search(prompt) or ERROR_MARKER.search(prompt)):
        return  # no artifact referenced
    if HYPOTHESIS.search(prompt):
        return  # user already posed a hypothesis/question
    emit(NUDGE)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open
