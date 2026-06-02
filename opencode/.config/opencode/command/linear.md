---
description: Work on Linear issue — fetch context, verify branch, TDD workflow
---

Work on Linear issue using TDD. Load `tdd` skill for implementation.

## Input

Issue: $1 — none? Ask user for identifier (e.g. EDU-4103).

## Steps

1. **Fetch issue** — use Linear MCP `get_issue` (with `includeRelations: true`). Extract: title, description, status, labels, parent, relations, `gitBranchName`.
2. **Branch check** — get current git branch. Compare with issue's `gitBranchName`.
   - Match → proceed.
   - Mismatch → **ABORT**. Tell user: expected branch `{gitBranchName}`, currently on `{current}`. Do not continue.
3. **Present context** — summarize issue: scope, requirements, blocking/blocked-by relations. Ask user to confirm understanding before coding.
4. **Implement via TDD** — follow `tdd` command workflow: red-green-refactor for each behavior in scope.

## Output

- Context summary (step 3): scope 1 line + ≤3 requirement bullets + blockers if any.
- No description restatement.
- Branch mismatch: 1 line (expected vs current).

## Rules

- All implementation uses TDD — no exceptions.
- Never start coding without branch verification passing.
- Respect issue scope — implement what described, nothing extra.
- If issue has `blocked-by` relations not done, warn user.
- Parent issue context = background info only. Implement child scope.
