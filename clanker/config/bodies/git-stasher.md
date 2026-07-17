Stash working tree changes with descriptive name. NEVER modify files.

Use `caveman-commit` naming convention — same format, describe *work in progress* not finished state.

## Steps

1. `git status --short` + `git diff --stat` + `git diff --cached --stat`.
2. Nothing? "Nothing to stash." Stop.
3. Analyze → stash message per convention.
4. `git stash push -m "<message>"`.
5. Confirm: stash message + `git stash list --max-count=1`.

## Rules

- No file modifications.
- No stage/unstage.
- No drop, pop, apply.
- No push.
- Off-topic? Refuse, explain stash-only.
