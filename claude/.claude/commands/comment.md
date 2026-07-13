---
description: Investigate code review comment — you commit your own read first, then AI reveals + TDD-fixes if confirmed
---

Investigate one review finding via the `driver-gate` **triage loop** (single item). Do NOT assume valid. The gate: on a load-bearing comment, AI withholds its verdict until YOU commit your own read — no thumbs-up on an analysis you didn't form. Load `driver-gate` (pattern) + `tdd` (fix phase).

## Input

Comment: $ARGUMENTS — none? Ask user to paste.

## Phase 1: Triage

Classify the comment (driver-gate mechanic 2):
- **Trivial/mechanical** (typo, rename, obvious nitpick, reversible one-liner) → say so, skip the gate, go to Phase 3 with a one-line plan. Don't manufacture a gate.
- **Load-bearing** (logic correctness, cross-layer, security/data integrity, wide blast radius) → Phase 2.

## Phase 2: Predict-first (load-bearing only)

1. Show the referenced code as `path:line` **anchors** + the question ("is this real, and why?"). **Do NOT state your verdict yet.**
2. **STOP. User commits their own read** — Real / False positive / Debatable, in their words. Skip only via `SKIP: <reason>` (carried into the close note as an un-owned decision).
3. **Reveal + challenge.** Now give AI's verdict + reasoning. Diverges from the user's read? Dig there. Then adversarially test the surviving call — what breaks if it's wrong. **STOP, wait for user** on how to proceed.

## Phase 3: Fix (user confirmed)

TDD — failing test demonstrating the issue → run, confirm fails → minimal fix → test passes → full suite, no regressions. Test change mid-impl → `tdd` rollback protocol.

## Output

- Trivial → 1 line (what + fix).
- Load-bearing → your read + AI verdict + divergence, each ≤1 line. Code as `path:line`. No comment restatement, no code dumps.
- False positive → say so, stop.

## Rules

- Never reveal AI's verdict on a load-bearing comment before the user commits theirs — that withholding IS the gate.
- Triage honestly; don't gate trivia (trains bypass) or wave through load-bearing (hands back the stamp).
- Never fix without user confirmation. All fixes TDD.
- Trivial fix → user might fix manually; offer.
