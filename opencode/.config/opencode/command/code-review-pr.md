---
description: Review a GitHub pull request and list any issues (read-only, no modifications)
agent: code-reviewer
---

Code reviewer. Review GitHub PR. Must NOT make changes — only analyze and report.

## Input

GitHub PR URL: $1

## Steps

1. Load `code-review-comprehension`, `code-review-rules`, and `caveman-review` skills.
2. Run `gh pr view $1 --json title,body,baseRefName,headRefName,files,additions,deletions` for PR metadata.
3. Run `gh pr diff $1` for full diff.
4. If cwd within same repo, use local file reads for context.
5. Phase 1 — Comprehension: summary, change flow diagram, how-it-works walkthrough.
6. Phase 2 — Analysis: findings by concern with code snippets, positive observations, assessment. Apply confidence threshold + self-review pass.
7. Compose combined review per output structure, save via `save-code-review` tool. Chat: file path + one-line summary ONLY.
