# Global Rules

- Before refactoring any code, ensure the existing behavior is fully covered by tests. Never proceed with a refactor until tests are in place that verify the current functionality is preserved.
- When implementing to make a test pass, write the absolute minimum code necessary — no more than what the test requires.
- When you look up documentation, conventions, or implementation patterns to decide how something should be done, suggest documenting the finding (e.g. in a skill, AGENTS.md, or project docs) so future sessions can reuse it without repeating the research.
- When research during planning uncovers project-specific patterns, conventions, or gotchas that are not yet documented in the relevant rules files (CLAUDE.md, AGENTS.md, skills, or context docs), include a step in the plan to document them. The documentation step should target the most specific relevant file (e.g. a service's CLAUDE.md for service-specific patterns, AGENTS.md for cross-cutting workflow rules).
- When editing a file, only change what is necessary to accomplish the task. Do not reformat, re-wrap, reorder, or otherwise alter surrounding content that is not related to the change. Unnecessary formatting changes make diffs noisy and large files hard to review.

## Custom commands

Every custom command in `command/` **must** have a dedicated subagent defined in `opencode.json` and referenced via `agent:` in the command's frontmatter. Never let a command run under the default primary agent.

### Adding a new command

1. **Define the subagent** in `opencode.json` under `agent`:
   - Set `"mode": "subagent"`.
   - Disable every tool the command does not need (`"write": false`, `"edit": false`, etc.).
   - Under `permission.bash`, default-deny everything (`"*": "deny"`) and allowlist only the specific command patterns required (e.g. `"git stash*": "allow"`).
2. **Create the command file** in `command/<name>.md`:
   - Add `agent: <subagent-name>` in the YAML frontmatter.
   - Write the instruction prompt for the subagent.
3. **Verify** that the command cannot perform actions outside its intended scope (e.g. it should not be able to write files, push to remote, or run arbitrary shell commands).

### Existing examples

| Command | Agent | Allowed bash patterns |
|---------|-------|-----------------------|
| `commit` | `git-committer` | `git diff*`, `git commit*`, `git status*` |
| `code-review` | `code-reviewer` | `git diff*`, `git log*`, `git status*`, `git rev-parse*`, `git show*`, `gh pr view*`, `gh pr diff*` |
| `stash` | `git-stasher` | `git stash*`, `git diff*`, `git status*` |
| `describe-pr` | `pr-describer` | *(bash disabled)* |
| `explain` | `explainer` | *(bash disabled)* |

### CRITICAL: Document research findings

After the research phase and BEFORE writing the plan steps, you MUST:

1. **List all patterns discovered** during research that are not already documented in CLAUDE.md, AGENTS.md, skills, or context docs.
2. **For each finding**, state which file it should be documented in.
3. **Include a plan step** to add the documentation.

If no undocumented patterns were found, explicitly state "No undocumented patterns discovered" in the plan. Skipping this section is not acceptable.

## When in plan mode

- Break work into small, focused steps — each step should represent a single logical change that can be implemented and verified independently.
- Provide concrete code samples for each step showing the expected changes, not just abstract descriptions.
- Each step should be small enough that it can be reviewed in isolation without needing full context of the entire plan.
- Prefer incremental steps that build on each other over large sweeping changes.
- When a step involves modifying existing code, show both the before and after to make the change clear.

### CRITICAL: Test-first ordering

**NEVER plan implementation before its tests.** Each plan step that introduces testable behaviour must be structured as two adjacent steps:

1. Write the test and verify that the specific new test cases fail for the expected reason — not just that "tests fail". Confirm the failure message matches the behaviour you are about to implement.
2. Write the minimum implementation to make it pass.

Never separate test and implementation steps with unrelated work. If the test requires importing a module that does not exist yet, create a minimal stub (e.g. an empty exported function) so the test fails at the assertion level, not the import level.

### CRITICAL: Integration verification

Unit tests alone are not sufficient. Every plan that adds or modifies an endpoint, service, or externally reachable behaviour **must** include a final integration verification step:

- When the project has e2e tests (e.g. SAM-based, Playwright), add e2e test cases for the new behaviour and run them.
- When e2e infrastructure is not available, include a manual verification step (e.g. CDK synth, curl against a running service, or smoke test) that proves the full wiring works — not just isolated units.
- This step must come after all unit-level TDD cycles are complete.

### CRITICAL: Plan submission checklist

Before calling `submit_plan`, verify EVERY item below. If any item is not addressed, revise the plan before submitting.

- [ ] Every testable step follows test-first ordering (test → stub → implementation)
- [ ] Integration/E2E tests are addressed:
  - If the project already has E2E infrastructure (e.g. `vitest.e2e.config.ts`, `globalSetup.e2e.ts`, Playwright configs, SAM-based test setup), include E2E tests in the plan
  - If no E2E infrastructure exists, ask the user whether to set it up or skip it
- [ ] All undocumented patterns discovered during research have a documentation step
- [ ] No implementation step lacks a corresponding verification step

## When in build mode

- When implementing to make a test pass, write the absolute minimum code necessary — no more than what the test requires.
- After all unit-level TDD cycles are complete, write and run e2e/integration tests if the project supports them. Never declare a task done based on unit tests alone when integration testing is available.
- After a code review completes, do NOT automatically fix or address any findings. Present the review to the user and wait for explicit instructions on what to fix.
