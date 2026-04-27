---
description: Fix a bug using TDD — write a failing test first, then implement the fix
---

Fix a bug using test-driven development. Load `tdd` skill — follow its red-green cycle and rollback protocol.

## Input

Bug description and context: $ARGUMENTS

If no bug description provided, ask the user to describe the bug.

## Steps

1. **Understand the bug** — Read relevant code, reproduce the issue mentally, identify root cause.
2. **Write a failing test** — Create a test that captures the exact buggy behavior. Run it to confirm it fails.
3. **Implement the fix** — Make the minimal change to fix the bug. Run the test to confirm it passes.
4. **Verify no regressions** — Run the full test suite for the affected area.

If test needs to change during implementation, follow the TDD rollback protocol from the `tdd` skill.
