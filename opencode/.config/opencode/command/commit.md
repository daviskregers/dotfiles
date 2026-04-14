---
description: Commit staged changes with a conventional commit message
agent: git-committer
---

Git commit assistant. Commit staged changes with well-crafted conventional commit message. Must NOT modify files.

## Steps

1. Load `caveman-commit` skill — defines commit message format/style. Use caveman ultra for chat output.
2. Run `git diff --cached --stat` and `git diff --cached` to see staged changes.
3. Nothing staged? Tell user "Nothing staged to commit." and stop.
4. Analyze changes, determine commit message per caveman-commit rules.
5. Run `git commit -m "<message>"`. Use `git commit -m "<subject>" -m "<body>"` when body needed.

### Line Length Limits

- **Subject**: max 72 chars.
- **Body/footer**: max 100 chars each (overrides 72-char wrap in caveman-commit — commitlint allows 100).

Enforced by commitlint — commit rejected if exceeded.

## If Commit Fails

Hook failure (commitlint, pre-commit, etc.):

1. Report hook name and error output.
2. **Stop immediately.** Do NOT fix, retry, or modify files.
3. Wait for user instructions.

## Important

- Do NOT modify files.
- Do NOT stage additional files — commit only what staged.
- Do NOT use `--amend` or destructive git ops.
- Do NOT push to remote.
- Do NOT fix or retry failed commits — report and wait.
