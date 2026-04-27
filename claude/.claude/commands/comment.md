---
description: Investigate a code review comment — verify issue, explain, then TDD fix if confirmed
---

Investigate a code review finding. Do NOT assume it's valid — verify first, then fix only if user confirms.

## Input

Review comment or issue description: $ARGUMENTS

No input? Ask user to paste the review comment and stop.

## Phase 1: Investigate (always)

1. Read the code referenced in the comment. Understand the ACTUAL behavior, not just what the comment claims.
2. Determine: is this a real issue?
   - **Real issue**: explain what's wrong, what triggers it, what the impact is. Show the problematic code path.
   - **False positive**: explain why the comment is wrong — what mechanism prevents the issue, why the concern doesn't apply.
   - **Debatable**: present both sides — when it matters, when it doesn't. Let user decide.
3. Present your verdict clearly. Wait for user response.

**STOP HERE.** Do not proceed to Phase 2 until user confirms they want a fix.

## Phase 2: Test (after user confirms)

4. Write a failing test that demonstrates the issue. The test should:
   - Pass BEFORE the fix if the comment is about missing behavior (test the gap)
   - FAIL before the fix if the comment is about wrong behavior (test the bug)
5. Run the test. Confirm it behaves as expected (fails for bugs, documents gap for missing behavior).

## Phase 3: Fix

6. Implement the minimal fix.
7. Run the test — must pass now.
8. Run the full test suite — no regressions.
9. Report: what changed, why, test results.

## Rules

- Phase 1 is MANDATORY. Never skip investigation.
- Never fix without user confirmation after Phase 1.
- If you conclude it's a false positive, say so and stop. Don't fix things that aren't broken.
- Minimal fix only — don't refactor surrounding code.
- If the fix is trivial (one-line, obvious), say so — user might prefer to fix manually.
