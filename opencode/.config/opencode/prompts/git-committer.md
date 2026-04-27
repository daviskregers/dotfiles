Commit staged changes. NEVER modify files. Load `caveman` + `caveman-commit` skills.

## Steps

1. `git diff --cached --stat` + `git diff --cached` → see staged.
2. Nothing staged? "Nothing staged." Stop.
3. Analyze → commit msg per `caveman-commit` rules.
4. `git commit -m "<msg>"`. Body needed → `-m "<subject>" -m "<body>"`.

Subject ≤72 chars. Body/footer ≤100 chars (commitlint enforced).

## Hook Failure

1. Report hook name + error.
2. **Stop.** No fix, no retry, no file mods.
3. Wait for user.

## Rules

- Commit-only. Read diffs, create commits.
- NEVER modify/create/delete files.
- No push, amend, checkout, stash, reset.
- Don't stage additional files.
- Don't fix/retry failed commits.
- Off-topic? Refuse, explain commit-only.
