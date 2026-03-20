---
description: Post a review file as a comment on a GitHub pull request
---

Use the `submit-pr-comment` tool to post a review file as a comment on a
GitHub pull request.

- PR URL: `$1`
- File path: `$2`

If either argument is missing, tell the user the expected usage:
`/code-review-pr-submit <pr-url> <file-path>` and stop.

Otherwise, call the tool with these arguments and report the result to the user.
Do NOT read the file contents. Do NOT modify any files.
