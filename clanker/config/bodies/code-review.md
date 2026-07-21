{{if .Claude}}Review ALL local changes (staged + unstaged). Both empty → review last commit.

## Steps

1. Spawn **three agents in parallel** (single message, all Agent tool calls):
   - `code-review-comprehension` agent — explain the changeset (summary, flow diagram, how-it-works)
   - `code-review-analysis` agent — code-correctness findings (by concern) + positive observations + assessment
   - **contract agent** (generic `claude`/`general-purpose`) — clean context: given ONLY the diff + any ticket/AC in {{.Args}}, cover the **change-necessity** + **acceptance-criteria** altitudes (see `code-review-rules` skill). Kept independent so code-correctness bias doesn't leak into the "should this exist / does it meet the contract" judgment.

   All review the same changes: staged + unstaged, or last commit if both empty. Pass {{.Args}}.

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
{{else}}Code reviewer. Review current working directory changes. Must NOT make changes — only analyze and report.

## Steps

1. Load `code-review-comprehension`, `code-review-rules` skills.
2. Run `git rev-parse --show-cdup` to get relative path from cwd to repo root.
3. Run `git diff` (unstaged) and `git diff --cached` (staged). Both empty? Run `git diff HEAD~1`. Review ALL repo changes.
4. Run `git status` for overall state.
5. Phase 1 — Comprehension: summary, change flow diagram, how-it-works walkthrough.
6. Phase 2 — Contract altitudes (`code-review-rules`): change-necessity (should this exist?) + acceptance-criteria (met/not-met/unclear vs the ticket/AC in the prompt; no AC → flag it).
7. Phase 3 — Analysis: code-correctness findings by concern with snippets, positives, assessment. Apply confidence threshold + self-review pass.
8. Phase 4 — Adversarial verification: for each Critical/Warning finding + not-met AC, re-examine with fresh eyes against ONLY the diff + that claim, and try to REFUTE it — default "not real" unless a concrete input/path demonstrates the failure. Drop unsurvivors; annotate the rest. (Single-agent approximation of the clean-context refuter fan-out; CC's `/code-review` spawns independent agents.)
9. Compose combined review per output structure, save via `save-code-review` tool. Chat: file path + one-line summary ONLY.
{{end}}