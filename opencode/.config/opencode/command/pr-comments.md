---
description: Socratic PR-comment triage — understand each review comment against the code before deciding, then reply/resolve and fan agreed fixes out to background subagents
---

Socratic PR-comment triage. A reviewer made claims; you decide what to do — but understand each one against the real code FIRST, never take the reviewer's framing on faith. User drives; you ask the questions that lead them to their own verdict. Same posture as `/investigate`. PR: $ARGUMENTS — none? infer from the current branch (`gh pr view --json url`), else ask.

## Setup

- Fetch once with `list_pr_comments` (unresolved only). Pull `read_pr_info` when you need the PR diff to see a comment in context.
- Order the queue: unresolved inline threads first (actionable), then review summaries, then conversation.
- Announce the count, then work ONE comment at a time. Never dump the whole queue.

## Rules (carry from /investigate)

- Lead with questions; withhold your read until the user commits their verdict.
- Primary sources first, UNBIASED — read the comment raw AND open the code it points at (`path:line`) before judging. The reviewer can be wrong; verify against the code, not the comment's wording.
- Ground every claim in evidence (read the code, fetch the diff). Never assert from memory.
- One comment, then STOP and wait. Don't chain.

## Per-comment arc

1. **Read it raw + locate the code.** Show the comment; open the referenced `path:line` and read that code together.
2. **What's the claim?** User restates the concern in their own words — what is the reviewer actually asserting?
3. **Does it hold?** Test against the code: valid / partial / misses context. Correct gently with the exact fact; don't seize the verdict.
4. **Options:** apply as-is · apply differently · push back with rationale · already-handled · defer.
5. **User decides.** Then act (below), and move to the next comment.

## Acting on a decision

- **Apply a fix → dispatch a background subagent** (`Agent`, `run_in_background: true`) with the comment, the `path:line`, and the agreed approach. Instruct it to fix via **TDD** (red→green→refactor) and to NOT commit (subagent commits are blocked; the main session commits). Move straight to the next comment while it runs.
- **Reply + resolve an inline thread →** `resolve_pr_thread` with the user's reasoning as `replyBody` (drafted from their words, not boilerplate).
- **Reply to a summary / conversation comment →** `submit_pr_comment`.
- **Push back / defer →** reply only, leave the thread unresolved.

## Close-out

Once the queue is worked: collect the background fixes, surface any that failed or need eyes, let the user review the diffs, then commit the batch from THIS session (never a subagent).
