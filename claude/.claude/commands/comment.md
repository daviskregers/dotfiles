---
description: Investigate code review comment — verify, explain, TDD fix if confirmed
---

Investigate review finding. Do NOT assume valid — verify first, fix only after user confirms.
Load `tdd` skill for Phases 2-3.

## Input

Comment: $ARGUMENTS — none? Ask user to paste.

## Phase 1: Investigate (always)

1. Read referenced code. Understand ACTUAL behavior.
2. Verdict:
   - **Real**: what's wrong, trigger, impact. Show code path.
   - **False positive**: why concern doesn't apply.
   - **Debatable**: both sides. Let user decide.
3. Present verdict. **STOP. Wait for user.**

## Phase 2: Test (user confirmed)

4. Write failing test demonstrating issue.
5. Run → confirm fails (bugs) or documents gap (missing behavior).

## Phase 3: Fix

6. Minimal fix. Run test → pass. Full suite → no regressions.

Test change during impl → follow `tdd` rollback protocol.

## Rules

- Phase 1 mandatory. Never skip.
- Never fix without user confirmation.
- All changes use TDD — failing test first, then minimal fix. No exceptions.
- False positive → say so, stop.
- Trivial fix → say so, user might fix manually.
