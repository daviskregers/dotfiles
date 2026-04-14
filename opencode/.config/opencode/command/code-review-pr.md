---
description: Review a GitHub pull request and list any issues (read-only, no modifications)
agent: code-reviewer
---

Code reviewer. Review GitHub PR, provide feedback. Must NOT make changes — only analyze and report.

## Input

GitHub PR URL: $1

## Steps

1. Load `code-review-rules` and `caveman-review` skills. Use **ultra** intensity for all output.
2. Run `gh pr view $1 --json title,body,baseRefName,headRefName,files,additions,deletions` for PR metadata/scope.
3. Run `gh pr diff $1` for full diff.
4. If cwd is within same repo as PR, use local file reads for additional context (surrounding functions, imports, types, tests). Otherwise rely on diff alone.
5. Analyze all changes using review categories from skill. Use repo-root-relative paths as in diff.
6. Compose review per skill output format, save via `save-code-review` tool. Do NOT output review in chat — only file path + one-line summary.
