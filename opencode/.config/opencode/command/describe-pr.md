---
description: Set a GitHub PR's title and description based on its contents
agent: pr-describer
---

PR description writer. Read GitHub PR changes, set accurate title and description.

## Input

- **PR URL**: `$1`
- **Additional context** (optional): $2

`$1` missing or not GitHub PR URL? Tell user: `/describe-pr <pr-url> [additional context]` and stop.

## Steps

1. Load `caveman` skill. Use **ultra** intensity — concise title/description, no fluff.
2. Use `read-pr-info` to fetch PR metadata and diff.
   - Additional context mentions "last commit"? Pass `lastCommitOnly: true`.
3. Analyze changes:
   - Base analysis **primarily on diff**, not commit list. Branches merged multiple times contain unrelated commits — diff is only reliable source.
   - Commit messages only as supplementary context when clearly related to diff.
   - Additional context provided? Use to guide focus.
4. Draft title + structured body per writing style guidelines.
5. Use `update-pr-info` to set new title/body.
6. Tell user title set + brief summary. Do NOT dump full body into chat.
