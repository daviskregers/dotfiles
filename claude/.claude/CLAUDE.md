# Global Rules

## Dual-setup sync

Changes to commands, skills, or agent prompts must be synced between Claude Code (`~/.dotfiles/claude/.claude/`) and opencode (`~/.dotfiles/opencode/.config/opencode/`). Skills = shared submodule but **separate clones** — commit in one, fetch into other (`git fetch <path> main`), checkout same commit, bump both pointers in parent. Commands/prompts: replicate manually. After any change, verify both submodule pointers match before committing parent.

## AI attribution

All AI-generated content posted to external systems ends with a final notice line: `🤖 Generated with AI`. Optionally append the model in parens, e.g. `🤖 Generated with AI (Claude Opus 4.8)`.

Applies to: PR descriptions, PR comments, Linear issues, Linear comments, commit messages (as the last line). Commit specifics: `git-commit` skill.

Do NOT use tool-branded attribution — no `Co-Authored-By` trailer, no "Generated with Claude Code"/"Generated with opencode". This notice replaces them.

## PR descriptions

Creating a PR (`gh pr create`, `/ship`, or ad-hoc) → author title/body via the `pr-describer` agent; NEVER write the description inline. It loads the `diagram` skill (mermaid architecture diagrams) + enforces the standard body structure. Flow: create PR with a stub body (`--title WIP --body _pending_`) → delegate to `pr-describer` with the PR URL → it reads the diff, sets title/body via `update_pr_info`.

After any `git push`, check the branch for an existing PR (`gh pr view --json url,number`). PR exists → the diff changed, so its description is stale → re-delegate to `pr-describer` (PR URL) to refresh title/body. No PR → nothing to do.

## TDD

Test-driven by default for ALL feature/bugfix/refactor/behavioural-narrowing work, every project & agent. Red-green-refactor: failing test first → confirm it fails for the right reason (test must call REAL production code, not a test-file duplicate) → minimal impl → confirm pass → refactor green → repeat per behavior. Bugs: replicate with a failing test before fixing. Deletions/tightening: assert the new contract with a failing test ("X now rejected") before stripping source — never skip TDD just because change is subtractive. If impl reveals the test needs changing: rollback impl → fix test → verify fail → re-implement (never edit test+impl together). Mechanics: `tdd` skill.

## Brevity

Default to terse. Applies to ALL output — responses, configs, subagent findings. Compress before presenting; never relay subagent walls-of-text verbatim.

Output caps:
- Status/confirmation: ≤3 sentences.
- Analysis/verdict: ≤6 lines or ≤5 bullets per dimension. Going longer needs justification.
- Code references: `path:line` form, not paragraph descriptions of code.
- No restatement of input (comment, prompt, ticket, diff).
- No trailing "what I did" summary — the diff/artifact shows it.
- Headers/sections only when ≥3 items warrant them.
- Final turn message: 1-2 sentences.

All rules, skills, prompts, commands, and agent definitions MUST be written compressed — drop articles/filler/hedging, use fragments, abbreviate. Technical substance, code blocks, and structure preserved — only fluff removed.

- Before refactoring, ensure existing behavior covered by tests. Never refactor without tests proving current functionality preserved.
- When implementing for test, write absolute minimum code — no more than test requires.
- Error/validation response tests assert both the HTTP status code AND the validation message/field (e.g. `assertStatus(422)` + the `errors.<field>` message), so wording/contract regressions are caught.
- When looking up docs/conventions/patterns, suggest documenting finding (skill, CLAUDE.md, project docs) so future sessions reuse without re-research.
- When research uncovers undocumented patterns/conventions/gotchas, include plan step to document them. Target most specific file (service CLAUDE.md for service-specific, CLAUDE.md for cross-cutting).
- When editing file, only change what necessary. No reformatting/reordering/re-wrapping unrelated content. Unnecessary changes = noisy diffs.
- Avoid repeated magic values. When the same logical value appears in multiple places, extract a named constant or derive it from one source unless there is a clear reason not to.
- Stepdown rule: order functions top-down by abstraction. Public/high-level first, private/helpers below. Each function followed by those it calls — file reads like a narrative descending through abstraction layers.
- Layered architecture — three swap boundaries: **Controllers** (comms + auth only, no business logic), **Services** (business logic, framework-agnostic, calls repositories), **Repositories** (persistence abstraction over DB/filesystem/S3). Change transport? Rewrite controllers. Change storage? Rewrite repos. Business logic stays stable through both. Flag logic in wrong layer.
