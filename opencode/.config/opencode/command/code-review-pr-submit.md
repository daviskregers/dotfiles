---
description: Post a review file as a comment on a GitHub pull request
agent: code-reviewer
---

Use `submit-pr-comment` tool to post review file as PR comment.

- PR URL: `$1`
- File path: `$2`

Either arg missing? Tell user: `/code-review-pr-submit <pr-url> <file-path>` and stop.

Otherwise call tool, report result. Do NOT read file contents. Do NOT modify files.
