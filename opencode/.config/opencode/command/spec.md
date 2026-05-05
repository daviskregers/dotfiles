---
description: Scaffold spec-driven development template pre-filled from context
---

Generate implementation spec for a task. Pre-fill context from git status + codebase.

## Steps

1. Run `git status` and `git diff --stat` to identify changed/relevant files.
2. If $ARGUMENTS provided, use as task description. Otherwise ask user.
3. Generate spec using template below, pre-filled with:
   - File paths from git status or user's description
   - Current behavior (read relevant files if needed)
   - Placeholder requirements user fills in

## Template

```
## Task: [description from $ARGUMENTS]

### Context
- Files: [auto-detected from git status or mentioned in description]
- Current behavior: [read from code if identifiable]
- Related: [prior work, tickets if mentioned]

### Requirements
1. [must/should + specific outcome]
2. [must/should + specific outcome]

### Constraints
- [what NOT to do — preserve existing behavior unless stated]

### Done when
- [testable outcome 1]
- [testable outcome 2]
```

4. Output spec as markdown in chat. User edits, then pastes back or confirms to proceed with implementation.

$ARGUMENTS
