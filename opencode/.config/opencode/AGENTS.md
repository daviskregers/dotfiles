# Global Rules

- Before refactoring, ensure existing behavior covered by tests. Never refactor without tests proving current functionality preserved.
- When implementing for test, write absolute minimum code — no more than test requires.
- When looking up docs/conventions/patterns, suggest documenting finding (skill, AGENTS.md, project docs) so future sessions reuse without re-research.
- When research uncovers undocumented patterns/conventions/gotchas, include plan step to document them. Target most specific file (service CLAUDE.md for service-specific, AGENTS.md for cross-cutting).
- When editing file, only change what necessary. No reformatting/reordering/re-wrapping unrelated content. Unnecessary changes = noisy diffs.

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
