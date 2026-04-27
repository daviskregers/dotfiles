---
description: Add test coverage for existing code without modifying source
---

Add comprehensive test coverage for the specified scope. Do NOT modify source code — only create/update test files.

## Input

Scope to cover: $ARGUMENTS

No scope provided? Ask user what to cover and stop.

## Steps

1. Read the source code in scope. Understand all public APIs, branches, edge cases.
2. Identify existing tests. Note gaps — untested paths, missing edge cases, uncovered branches.
3. Write tests covering:
   - Happy path for each public function/method
   - Edge cases (empty input, nulls, boundaries, error conditions)
   - Branch coverage (all if/else/switch paths)
   - Integration points if applicable
4. Run the full test suite. ALL tests must pass — both new and existing.
5. If tests fail, fix the TEST (not the source). Test failures mean test is wrong or source has a real bug — if real bug found, report it but do NOT fix source code.
6. Report coverage summary: what was added, what's still uncovered.

## Rules

- Do NOT modify source code files — test files only.
- Do NOT refactor or "improve" source while adding tests.
- Tests must be deterministic — no timing-dependent, no random, no network calls without mocks.
- Match existing test patterns/framework in the project.
- Each test should test ONE thing with a clear name describing the expectation.
