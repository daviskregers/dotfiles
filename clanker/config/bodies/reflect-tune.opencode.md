Translate a root cause found by `/reflect` into concrete changes to *how Claude works for me* — CLAUDE.md/AGENTS.md rules, skills, commands, hooks. **Propose only; I approve each; you never decide for me.** The whole point is that I own the change to my own workflow — do not close the loop silently.

Target = `$ARGUMENTS` (a note path) or, if empty, the newest file in `/Users/daviskregers/Documents/Clank/Reflections/`.

## 1. Load

1. Read the target reflection note. None exist → tell me to run `/reflect` first, stop.
2. **Gate on relevance.** Only proceed if the root cause is about *how I work* — my coding practice, tooling, AI-usage habits, workflow. A bug triage, a system regression, a purely personal decision → output "nothing to tune here" and stop. Don't manufacture config changes.

## 2. Derive

Read current config: `~/.dotfiles/opencode/.config/opencode/AGENTS.md`, and (as relevant) the skills/, command/, opencode.json. For each thread in the note's root cause + "at stake" / "next action", ask: *is there a config change that would protect this as a standing guardrail?* Examples of shapes (not a menu — fit the note):
- An AGENTS.md rule (e.g. "explain the code you ship so I retain understanding before it merges").
- A skill/command that enforces a habit (a pre-ship comprehension gate, an AI-free step).
- A hook (automated before/after behavior).
- Sometimes the right move is *removing* a rule that's feeding the root cause.

Reject changes that just add more AI mediation to a root cause that's *about* too much AI mediation. Name that tension if it comes up.

## 3. Propose

Present each candidate as: **what** (concrete diff / file), **why** (which thread it protects), **cost** (what it constrains). Then ask me which to apply. Apply nothing un-approved.

## 4. Apply + dual-sync

For each approved change, edit the file, then sync per global dual-setup rules:
- **AGENTS.md / prompts:** replicate manually into `~/.dotfiles/claude/.claude/CLAUDE.md` (+ `commands/`, prompts).
- **Commands:** replicate `~/.dotfiles/opencode/.config/opencode/command/X.md` ↔ `~/.dotfiles/claude/.claude/commands/X.md`.
- **Skills:** commit in one skills clone → `git fetch` that path into the other clone → checkout same commit → bump both submodule pointers. Verify both pointers match before any parent commit.
- **Hooks/settings:** edit the relevant settings/config file.

Do NOT commit unless I ask. End with: the files changed, and the one-line root cause they trace back to.
