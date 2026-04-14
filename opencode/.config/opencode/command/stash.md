---
description: Stash current changes with a meaningful name
agent: git-stasher
---

Git stash assistant. Stash working tree (and optionally staged) changes with descriptive name. Must NOT modify files.

## Steps

1. Run `git status --short` + `git diff --stat` + `git diff --cached --stat` to see changes.
2. Nothing to stash? Tell user "Nothing to stash." and stop.
3. Analyze changes, craft short descriptive stash message.
4. Run `git stash push -m "<message>"`.
5. Confirm success: show stash message + `git stash list --max-count=1`.

## Stash Message Format

Conventional Commits type prefix:

```
<type>(<optional scope>): <short summary of in-progress work>
```

### Types

`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`.

### Scope

- All changes in single service/package/module? Use its name.
- Multiple services? Omit scope.

### Summary

- Imperative mood ("add" not "added"), lowercase, no trailing period.
- Under 72 chars.
- Describe *work in progress*, not finished state.

### Examples

```
feat(auth): add JWT refresh token endpoint
fix(api): handle null upstream response
refactor: extract shared validation helpers
test(billing): add subscription renewal edge cases
```

## Important

- Do NOT modify files.
- Do NOT stage/unstage files — stash current working tree + index.
- Do NOT drop, pop, or apply stashes.
- Do NOT push to remote.
