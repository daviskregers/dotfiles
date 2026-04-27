---
description: Refactor code safely — validate test coverage first, refactor, verify tests still pass
---

Refactor the specified scope. Tests are the safety net — verify they exist and pass BEFORE touching source.
Load `tdd` skill — tests are the contract, follow its regression check rules.

## Input

What to refactor: $ARGUMENTS

No scope provided? Ask user what to refactor and stop.

## Steps

### Phase 1: Validate test coverage

1. Read the source code in scope. Understand current behavior.
2. Find existing tests covering this code. Run them — they MUST pass.
3. Assess coverage: are the critical paths tested? If coverage is insufficient:
   - **STOP.** Report what's missing.
   - Tell user to run `/test-cover <scope>` first.
   - Do NOT proceed until user confirms coverage is acceptable.

### Phase 2: Refactor

4. Only after tests pass — plan the refactor. State what you'll change and why.
5. Make changes incrementally. After each logical change:
   - Run the test suite
   - Tests fail → revert that change, diagnose, try different approach
   - Tests pass → continue

### Phase 3: Verify

6. Run the FULL test suite (not just scoped tests). No regressions allowed.
7. Report: what changed, why, test results.

## Rules

- NEVER refactor without passing tests first. Tests are the contract.
- Behavior must be preserved — refactor changes structure, not behavior.
- If tests fail after refactor, fix or revert your refactor. Do NOT modify tests to make them pass.
- Keep changes minimal. Don't scope-creep into "improvements" beyond what was asked.
- If you discover a real bug during refactor, report it separately — don't silently fix it.
