---
description: Build feature/change using TDD — test first, verify fail, minimal impl to pass
---

TDD workflow. Load `tdd` skill — red-green-refactor cycle + rollback protocol.

## Input

Task: $1 — none? Ask user.

## Steps

1. **Understand** — read code, clarify requirements, identify scope.
2. **Red** — write test capturing expected behavior. Run → confirm FAILS. No impl yet.
3. **Green** — minimal code to pass test. Nothing extra. Run → confirm passes.
4. **Refactor** — clean up impl + test. Run → confirm still passes.
5. **Repeat** — next behavior? Back to step 2. Continue until task complete.
6. **Regressions** — full suite for affected area.

## Rules

- Test MUST fail before impl. Pass without impl = test proves nothing.
- Minimal impl only — no more than test requires.
- One behavior per red-green cycle. Small steps.
- Test change during impl → follow `tdd` rollback protocol.
- Changing existing contract with tests → follow `tdd` contract migration protocol.
- No scope creep. Implement what asked, nothing extra.
