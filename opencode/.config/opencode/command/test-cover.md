---
description: Add test coverage without modifying source
---

Add test coverage for scope. Do NOT modify source — test files only.
Load `tdd` skill — follow test quality rules.

## Input

Scope: $1 — none? Ask user.

## Steps

1. Read source. Understand APIs, branches, edge cases.
2. Find existing tests. Note gaps.
3. Write tests per `tdd` quality rules: happy path, edge cases, branch coverage, integration points.
4. Run full suite. ALL must pass.
5. Test fails → fix TEST not source. Real bug → report, don't fix source.
6. Report: added, still uncovered.

## Rules

- Source files untouched — test files only.
- No refactoring source while adding tests.
