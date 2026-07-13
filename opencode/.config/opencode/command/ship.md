---
description: Local review → validate → commit → push → draft PR → Copilot review → triage
---

Pipeline: local review (pre-commit) → pause → commit → push → draft PR → Copilot → PR-comment triage.
`--no-review` skips both review phases (plain commit → push → PR → Copilot).

## Input

Target base branch (+ optional `--ready`, `--no-review`, title/context): $1 — no base given? Ask.
Load `git-commit` (commit message) + `driver-gate` (triage loop, Phases A & D).

## Phase A — Local review (pre-commit; skip if `--no-review`)

1. Review the **working tree** (`git diff` + `git diff --cached`; both empty → last commit): spawn `code-review-analysis` agent → structured findings. Then run the `driver-gate` **triage loop** over them: per finding, triage (trivial → fast; load-bearing → show anchors, **withhold AI verdict, user commits their read first**, reveal + challenge) → **STOP** → fix (TDD) / skip via `SKIP:`. Don't commit here — that's Phase C.

## Phase B — Validate (pause)

2. Summarize: changed files, findings handled, what's staged vs unstaged.
   **STOP. Wait for user to stage what they want and confirm it's commit-worthy.** Do not commit before this.

## Phase C — Ship

3. **Commit** (staged-only, main session — never spawn a subagent to commit):
   - `git diff --cached --stat`. Staged → conventional message per `git-commit`, `git commit`.
   - Nothing staged but branch has unpushed commits → skip to push. Nothing at all → stop: "Nothing to ship."
4. **Push**: `git push -u origin $(git branch --show-current)`. Never force-push.
5. **PR**: branch already has a PR? (`gh pr view --json url,number`) → reuse. Else `gh pr create --base <BASE> --draft --title WIP --body _pending_` (drop `--draft` if `--ready`). **Then delegate title/body to the `pr-describer` agent** (pass PR URL) — it reads the diff and authors title + body (mermaid diagrams per `diagram` skill) via `update_pr_info`. Never write the description inline.
6. **Copilot review**: call `request_copilot_review` with the PR URL.

## Phase D — PR-comment triage (skip if `--no-review`)

7. `wait_for_copilot_review` (PR URL), then `list_pr_comments` → queue of Copilot + human/existing comments.
8. **Triage + close** per `/comments` Phases 2–4: one-at-a-time fix with a per-fix user-reviewed commit → single `git push` → reply + resolve each thread. **Leave PR draft** (never auto-ready).
9. **Report**: findings/comments handled, fixed/skipped, PR URL, still-draft. 1–2 lines.

## Rules

- Base branch is explicit (arg) — if missing, ask; never guess.
- Local review happens BEFORE commit; always pause (Phase B) for user validation before committing.
- Staged-only commit. Don't stage extra files.
- Triage is one-at-a-time (driver-gate) — never batch verdicts; load-bearing items withhold AI's verdict until the user commits their read. Never marks the PR ready.
- Halt the chain on any step failure (commit hook, push reject, PR error); report + stop, don't retry blindly.
