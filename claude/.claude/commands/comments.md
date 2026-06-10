---
description: Bulk-read all PR comments, then investigate each via /comment one-at-a-time
---

Bulk-fetch a PR's comments, build a queue, walk each through the `/comment` flow sequentially.
Each fix → its own commit (user-reviewed). One push at the end, then reply + resolve all.
Load `tdd` skill (fix phases), `git-commit` (per-fix commits).

## Input

PR URL/number: $ARGUMENTS — none? Resolve current branch's PR via `gh pr view --json url,number`. No PR? Ask.

## Phase 0: Bulk read

1. Resolve PR URL: `$ARGUMENTS`, else `gh pr view --json url`.
2. Call `list_pr_comments` (MCP) → normalized JSON queue: `items[]` with `index, kind (inline|review|conversation), threadId, path, line, author, body, url`, plus `total` + `skippedResolved`. Resolved threads + empty bodies already filtered.

## Phase 1: Present queue

List numbered: `N. path:line — author — one-line gist`. State total actionable + skipped.

## Phase 2: Triage one-at-a-time (fix + per-fix commit; NO reply/resolve yet)

For each item, in order:
1. Header: `Comment N/total — path:line — author`. Then **quote the comment body verbatim** (blockquote) so the user sees what it refers to, with its `url`.
2. Run the `/comment` flow: Phase 1 investigate → verdict (Real / False positive / Debatable) → **STOP, wait for user**.
3. Outcome:
   - **Fix**: TDD (failing test → minimal fix → suite). Then **STOP — show the diff; user reviews.** On approval, commit as a **separate commit** (staged-only, conventional msg per `git-commit`; exactly one commit per fixed comment). Record commit sha.
   - **Ignore / false positive**: no change.
4. Record the close note for later (fixed → what changed + commit sha; ignored → why). **Do NOT reply or resolve yet.**
5. Advance to N+1.

## Phase 3: Push (once, after all items)

Single `git push` of all the per-fix commits. Nothing fixed → skip.

## Phase 4: Reply + resolve

For each handled item, post its recorded close note then resolve:
- Inline (`threadId`): `resolve_pr_thread` with `threadId` + `replyBody` (reply, then resolve).
- Review/conversation (`threadId` null): reply via `gh pr comment`, nothing to resolve.
Confirm reply text with user before posting (outward-facing).

## Rules

- Never batch verdicts — strictly one comment, one stop.
- Phase 1 investigation mandatory per item; never assume a comment valid.
- No fix without user confirmation. All fixes TDD. User reviews the diff before every commit.
- One commit per fix. Reply/resolve happen only in Phase 4, after the single push.
- Always quote the comment body being triaged — the user needs the original to judge. Verdict/analysis stays terse; code as `path:line`.
- Track progress visibly (`N/total`).
