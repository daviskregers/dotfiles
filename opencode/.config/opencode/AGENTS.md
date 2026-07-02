# Global Rules

## Dual-setup sync

Changes to commands, skills, or agent prompts must be synced between Claude Code (`~/.dotfiles/claude/.claude/`) and opencode (`~/.dotfiles/opencode/.config/opencode/`). Skills = shared submodule but **separate clones** — commit in one, fetch into other (`git fetch <path> main`), checkout same commit, bump both pointers in parent. Commands/prompts: replicate manually. After any change, verify both submodule pointers match before committing parent.

## AI attribution

All AI-generated content posted to external systems ends with a final notice line: `🤖 Generated with AI`. Optionally append the model in parens, e.g. `🤖 Generated with AI (Kimi K2.6)`.

Applies to: PR descriptions, PR comments, Linear issues, Linear comments, commit messages (as the last line). Commit specifics: `git-commit` skill.

Do NOT use tool-branded attribution — no `Co-Authored-By` trailer, no "Generated with Claude Code"/"Generated with opencode". This notice replaces them.

## PR descriptions

Creating a PR (`gh pr create`, `/ship`, or ad-hoc) → author title/body via the `pr-describer` agent; NEVER write the description inline. It loads the `diagram` skill (mermaid architecture diagrams) + enforces the standard body structure. Flow: create PR with a stub body (`--title WIP --body _pending_`) → delegate to `pr-describer` with the PR URL → it reads the diff, sets title/body via `update-pr-info`.

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
- When looking up docs/conventions/patterns, suggest documenting finding (skill, AGENTS.md, project docs) so future sessions reuse without re-research.
- When research uncovers undocumented patterns/conventions/gotchas, include plan step to document them. Target most specific file (service CLAUDE.md for service-specific, AGENTS.md for cross-cutting).
- When editing file, only change what necessary. No reformatting/reordering/re-wrapping unrelated content. Unnecessary changes = noisy diffs.
- Avoid repeated magic values. When the same logical value appears in multiple places, extract a named constant or derive it from one source unless there is a clear reason not to.
- Stepdown rule: order functions top-down by abstraction. Public/high-level first, private/helpers below. Each function followed by those it calls — file reads like a narrative descending through abstraction layers.

## Custom commands

Every command in `command/` **must** have dedicated subagent in `opencode.json` via `agent:` frontmatter. Never run under default agent.

### Adding new command

1. **Define subagent** in `opencode.json` under `agent`:
   - `"mode": "subagent"`.
   - Disable unneeded tools (`"write": false`, `"edit": false`, etc.).
   - `permission.bash`: default-deny (`"*": "deny"`), allowlist only needed patterns.
2. **Create command file** `command/<name>.md`:
   - `agent: <subagent-name>` in YAML frontmatter.
   - Write instruction prompt.
3. **Verify** command can't act outside intended scope (no file writes, no push, no arbitrary shell).

### Existing examples

| Command | Agent | Allowed bash |
|---------|-------|-----------------------|
| `commit` | `git-committer` | `git diff*`, `git commit*`, `git status*` |
| `code-review` | `code-reviewer` | `git diff*`, `git log*`, `git status*`, `git rev-parse*`, `git show*`, `gh pr view*`, `gh pr diff*` |
| `stash` | `git-stasher` | `git stash*`, `git diff*`, `git status*` |
| `describe-pr` | `pr-describer` | *(bash disabled)* |
| `explain` | `explainer` | *(bash disabled)* |

### CRITICAL: Document research findings

After research, BEFORE plan steps:

1. **List all discovered patterns** not in CLAUDE.md/AGENTS.md/skills/context docs.
2. **For each**, state target doc file.
3. **Include plan step** to add documentation.

No findings? State "No undocumented patterns discovered". Never skip.

## Plan mode

- Small focused steps — single logical change, independently verifiable.
- Concrete code samples each step, not abstract descriptions.
- Each step reviewable in isolation.
- Incremental steps over sweeping changes.
- Show before/after when modifying existing code.

### CRITICAL: Test-first ordering

**NEVER plan impl before tests.** Testable steps = two adjacent steps:

1. Write test, verify it fails for expected reason. Confirm failure message matches behavior about to implement.
2. Write minimum impl to pass.

Never separate test/impl with unrelated work. Missing module? Create minimal stub so test fails at assertion, not import.

### CRITICAL: Integration verification

Unit tests not sufficient. Plans adding/modifying endpoints/services/external behavior **must** include integration verification:

- Project has e2e (SAM, Playwright)? Add e2e cases, run them.
- No e2e infra? Manual verification step (CDK synth, curl, smoke test) proving full wiring works.
- Must come after all unit TDD cycles.

### CRITICAL: Plan submission checklist

Verify EVERY item before `submit_plan`:

- [ ] Every testable step: test-first (test → stub → impl)
- [ ] Integration/E2E addressed:
  - E2E infra exists? Include E2E tests
  - No E2E infra? Ask user whether to set up or skip
- [ ] Undocumented patterns have documentation step
- [ ] No impl step without verification step

## Build mode

- Implement minimum code for test — no more than required.
- After unit TDD done, write/run e2e/integration tests if project supports. Never declare done on unit tests alone when integration available.
- After code review, do NOT auto-fix findings. Present to user, wait for instructions.
