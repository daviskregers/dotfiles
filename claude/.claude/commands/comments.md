---
description: Bulk-read all PR comments, then investigate each via /comment one-at-a-time
---

Bulk-fetch a PR's comments, build a queue, walk each through the `/comment` flow sequentially.
Load `tdd` skill (fix phases reuse it).

## Input

PR URL/number: $ARGUMENTS — none? Resolve current branch's PR via `gh pr view --json url,number`. No PR? Ask.

## Phase 0: Bulk read

1. Resolve PR URL: `$ARGUMENTS`, else `gh pr view --json url`.
2. Call `list_pr_comments` (MCP) → normalized JSON queue: `items[]` with `index, kind (inline|review|conversation), threadId, path, line, author, body, url`, plus `total` + `skippedResolved`. Resolved threads + empty bodies already filtered.

## Phase 1: Present queue

List numbered: `N. path:line — author — one-line gist`. State total actionable + skipped.

## Phase 2: Walk one-at-a-time

For each item, in order:
1. Header: `Comment N/total — path:line — author`. Then **quote the comment body verbatim** (blockquote) so the user sees what it refers to, with its `url`.
2. Run the `/comment` flow: Phase 1 investigate → verdict (Real / False positive / Debatable) → **STOP, wait for user**.
3. User picks outcome:
   - **Fix**: TDD (failing test → minimal fix → suite). Trivial → user may fix manually.
   - **Ignore / false positive**: no code change.
4. Close (default for BOTH outcomes): call `resolve_pr_thread` with `threadId` + `replyBody` (fixed → what changed, `path:line`; ignored → why). Posts reply then resolves.
   Confirm reply text with user before the call (outward-facing).
   Non-inline items (`kind` review/conversation, `threadId` null) → reply via `gh pr comment`, nothing to resolve.
5. Only after item N closed, advance to N+1.

## Rules

- Never batch verdicts — strictly one comment, one stop.
- Phase 1 investigation mandatory per item; never assume a comment valid.
- No fix without user confirmation. All fixes TDD.
- Always quote the comment body being triaged — the user needs the original to judge. Verdict/analysis stays terse; code as `path:line`.
- Track progress visibly (`N/total`).
