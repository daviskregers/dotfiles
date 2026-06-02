---
description: Refactor safely — validate tests first, refactor, verify pass
---

Refactor scope. Tests = safety net — must exist and pass BEFORE touching source.
Load `tdd` skill — tests are contract.

## Input

Scope: $ARGUMENTS — none? Ask user.

### Phase 1: Validate coverage

1. Read source. Understand behavior.
2. Find tests. Run → MUST pass.
3. Coverage insufficient? **STOP.** Report gaps. Tell user `/test-cover <scope>` first.

### Phase 2: Refactor

4. Plan changes. State what/why.
5. Incremental changes. After each: run tests → fail? revert, diagnose → pass? continue.

### Phase 3: Verify

6. FULL suite (not just scoped). No regressions.
7. Report: what changed, why, results.

## Output

- Plan (step 4): ≤5 bullets, what + why per bullet.
- Final report (step 7): ≤3 lines. No source restatement.
- Per-step status: 1 line each (pass/fail + which test).

## Rules

- Never refactor without passing tests.
- Behavior preserved — structure changes, not behavior.
- Tests fail after refactor → fix/revert refactor, NOT tests.
- No scope creep.
- Real bug found → report separately, don't silently fix.
