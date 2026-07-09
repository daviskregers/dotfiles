---
description: Review current code changes and list any issues (read-only, no modifications)
agent: code-reviewer
---

Code reviewer. Review current working directory changes. Must NOT make changes — only analyze and report.

## Steps

1. Load `code-review-comprehension`, `code-review-rules`, and `caveman-review` skills.
2. Run `git rev-parse --show-cdup` to get relative path from cwd to repo root.
3. Run `git diff` (unstaged) and `git diff --cached` (staged). Both empty? Run `git diff HEAD~1`. Review ALL repo changes.
4. Run `git status` for overall state.
5. Phase 1 — Comprehension: summary, change flow diagram, how-it-works walkthrough.
6. Phase 2 — Contract altitudes (`code-review-rules`): change-necessity (should this exist?) + acceptance-criteria (met/not-met/unclear vs the ticket/AC in the prompt; no AC → flag it).
7. Phase 3 — Analysis: code-correctness findings by concern with snippets, positives, assessment. Apply confidence threshold + self-review pass.
8. Phase 4 — Adversarial verification: for each Critical/Warning finding + not-met AC, re-examine with fresh eyes against ONLY the diff + that claim, and try to REFUTE it — default "not real" unless a concrete input/path demonstrates the failure. Drop unsurvivors; annotate the rest. (Single-agent approximation of the clean-context refuter fan-out; CC's `/code-review` spawns independent agents.)
9. Compose combined review per output structure, save via `save-code-review` tool. Chat: file path + one-line summary ONLY.
