---
description: Local review → validate → commit → push → draft PR → Copilot review → triage
---

Pipeline: local review (pre-commit) → pause → commit → push → draft PR → Copilot → PR-comment triage.
`--no-review` skips both review phases (plain commit → push → PR → Copilot).

## Input

Target base branch (+ optional `--ready`, `--no-review`, title/context): $ARGUMENTS — no base given? Ask.
Load `git-commit` skill for the commit message.

## Phase A — Local review (pre-commit; skip if `--no-review`)

1. Run the `/review-fix` flow (Phases 1–3): review the working tree → present findings → triage one-at-a-time (show finding → investigate → verdict → **STOP** → fix/skip). Don't commit here — that's Phase C.

## Phase B — Validate (pause)

2. Summarize: changed files, findings handled, what's staged vs unstaged.
   **STOP. Wait for user to stage what they want and confirm it's commit-worthy.** Do not commit before this.

## Phase C — Ship

3. **Commit** (staged-only, main session — never spawn a subagent to commit):
   - `git diff --cached --stat`. Staged → conventional message per `git-commit`, `git commit`.
   - Nothing staged but branch has unpushed commits → skip to push. Nothing at all → stop: "Nothing to ship."
4. **Push**: `git push -u origin $(git branch --show-current)`. Never force-push.
5. **PR**: branch already has a PR? (`gh pr view --json url,number`) → reuse. Else `gh pr create --base <BASE> --draft --title <t> --body <b>` (drop `--draft` if `--ready`). Title/body from commits + diff.
6. **Copilot review**: call `request_copilot_review` with the PR URL.

## Phase D — PR-comment triage (skip if `--no-review`)

7. `wait_for_copilot_review` (PR URL), then `list_pr_comments` → queue of Copilot + human/existing comments.
8. **Triage** per `/comments` Phase 2 — one-at-a-time, show the comment first, close per its rules (inline → reply + `resolve_pr_thread`; review/conversation → reply, nothing to resolve).
9. **Push fixes**: triage fix commits → commit (staged-only) + `git push`. **Leave PR draft** (never auto-ready).
10. **Report**: findings/comments handled, fixed/skipped, PR URL, still-draft. 1–2 lines.

## Rules

- Base branch is explicit (arg) — if missing, ask; never guess.
- Local review happens BEFORE commit; always pause (Phase B) for user validation before committing.
- Staged-only commit. Don't stage extra files.
- Triage is one-at-a-time — never batch verdicts, always show the finding/comment text. Never marks the PR ready.
- Halt the chain on any step failure (commit hook, push reject, PR error); report + stop, don't retry blindly.
