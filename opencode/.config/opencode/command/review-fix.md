---
description: Review working-tree changes, triage findings one-at-a-time, fix (no PR)
---

Local code review → interactive triage → fix. No push/PR — works in any repo.
Load `tdd` skill (fixes); `caveman-commit` if committing.

## Phase 1: Review

Review the **working tree** (`git diff` + `git diff --cached`; both empty → last commit) per `code-review-rules` + `caveman-review` skills. Optional context: $1.
Produce a STRUCTURED findings list (each: title, `path:line`, severity, concern, rationale).
(Reviewed inline as one agent — intentional: the Claude twin spawns a `code-review-analysis` subagent, same findings contract.)

## Phase 2: Present queue

List numbered: `N. severity path:line — title`. State total.

## Phase 3: Triage one-at-a-time

For each finding, in order:
1. Header `Finding N/total — severity — path:line`. **Show the finding** (title + concern + rationale) so the user sees what it refers to.
2. Investigate the referenced code → verdict (Real / False positive / Debatable) → **STOP, wait for user**.
3. Outcome: **Fix** (TDD: failing test → minimal fix → suite) or **skip**. Mark done.
4. Advance to N+1 only after N closed.

## Phase 4 (optional): Commit

User asks to commit → staged-only conventional commit per `caveman-commit`.

## Rules

- One finding, one stop — never batch verdicts.
- Always show the finding text. Verdict/analysis terse; code as `path:line`.
- No fix without user confirmation. All fixes TDD.
- Read-only review; modify only on a confirmed fix.
