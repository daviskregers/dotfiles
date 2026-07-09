---
description: Review current code changes (read-only, saves to .dk-notes/reviews/)
---

Review ALL local changes (staged + unstaged). Both empty → review last commit.

## Steps

1. Spawn **three agents in parallel** (single message, all Agent tool calls):
   - `code-review-comprehension` agent — explain the changeset (summary, flow diagram, how-it-works)
   - `code-review-analysis` agent — code-correctness findings (by concern) + positive observations + assessment
   - **contract agent** (generic `claude`/`general-purpose`) — clean context: given ONLY the diff + any ticket/AC in $ARGUMENTS, cover the **change-necessity** + **acceptance-criteria** altitudes (see `code-review-rules` skill). Kept independent so code-correctness bias doesn't leak into the "should this exist / does it meet the contract" judgment.

   All review the same changes: staged + unstaged, or last commit if both empty. Pass $ARGUMENTS.

2. **Adversarial verification.** If analysis + contract produced any Critical/Warning findings or not-met ACs, spawn one refuter agent **per such finding, in parallel**, each with CLEAN context — only the diff + that single claim, NOT the reviewer's reasoning. Each tries to REFUTE it, defaulting to "not a real issue" unless it demonstrates the failure with a concrete input/path. Drop findings that don't survive; annotate survivors with residual uncertainty. No material findings → skip. (Suggestions / optimizations / `❓ q:` are not verified.)

3. Combine surviving outputs into single markdown artifact:

   ```
   > **🤖 Generated with AI.**
   > Use your own judgment — findings may contain false positives or miss real issues.

   <comprehension agent output>

   <contract: change-necessity + acceptance-criteria>

   <verified analysis findings + positives + assessment>
   ```

4. Save combined review via `save_code_review` MCP tool, or write to `.dk-notes/reviews/review_YYYY-MM-DD_HH-MM-SS.md`.

5. Chat output: file path + one-line summary ONLY. Never dump review in chat.
