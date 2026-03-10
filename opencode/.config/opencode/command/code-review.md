---
description: Review current code changes and list any issues (read-only, no modifications)
---

You are a code reviewer. Your job is to review the current changes in the working directory and provide feedback. You must NOT make any changes to the code — only analyze and report.

## Steps

1. Run `git diff` to see unstaged changes and `git diff --cached` to see staged changes. If both are empty, run `git diff HEAD~1` to review the last commit.
2. Run `git status` to understand the overall state of the repository.
3. Analyze all changes thoroughly and produce a review covering the categories below.

## Review Categories

For each issue found, reference the file path and line number(s).

### Critical Issues
- Bugs or logic errors
- Security vulnerabilities
- Data loss risks

### Warnings
- Performance concerns
- Error handling gaps
- Race conditions or concurrency issues
- Missing input validation

### Suggestions
- Code style and readability improvements
- Naming improvements
- Opportunities to reduce duplication
- Missing or inadequate comments on complex logic

### Positive Observations
- Well-written code worth noting
- Good patterns or practices used

## Output Format

Output each issue in grep-style format, one per line:

```
file/path.ts:42: [critical] description of the issue
file/path.ts:87: [warning] description of the issue
file/path.ts:120: [suggestion] description of the issue
```

Use the severity tags: `[critical]`, `[warning]`, `[suggestion]`.

If there are no issues, output "No issues found."

At the end, provide a short overall assessment (1-2 sentences) after a blank line.

## Save to File

After producing the review output, save it using a single bash command:

```bash
mkdir -p .code-review && echo '<REVIEW_CONTENT>' > ".code-review/$(date +%Y-%m-%d_%H-%M-%S).md"
```

Replace `<REVIEW_CONTENT>` with the full review text. Use a heredoc if the content contains single quotes. Tell the user the file path where the review was saved.

## Important

- Do NOT modify any source code files.
- Do NOT suggest fixes inline by editing — only describe the issues.
- The ONLY file you may create is the review output under `.code-review/`.
