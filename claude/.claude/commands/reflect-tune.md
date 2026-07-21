---
description: Turn a reflection's root cause into proposed Claude-config guardrails — propose diffs, you approve, then dual-sync
argument-hint: [path to a Reflections note — defaults to the latest]
allowed-tools: Read, Edit, Write, Bash, Glob, Grep, AskUserQuestion
---

Translate a root cause found by `/reflect` into concrete changes to *how Claude works for me* — CLAUDE.md rules, skills, commands, hooks. **Propose only; I approve each; you never decide for me.** The whole point is that I own the change to my own workflow — do not close the loop silently.

Target = `$ARGUMENTS` (a note path) or, if empty, the newest file in `~/Documents/Clank/Reflections/`.

## 1. Load

1. Read the target reflection note. None exist → tell me to run `/reflect` first, stop.
2. **Gate on relevance.** Only proceed if the root cause is about *how I work* — my coding practice, tooling, AI-usage habits, workflow. A bug triage, a system regression, a purely personal decision → output "nothing to tune here" and stop. Don't manufacture config changes.

## 2. Derive

Read current config: `~/.dotfiles/claude/.claude/CLAUDE.md`, and (as relevant) `~/.dotfiles/claude/.claude/skills/`, `.../commands/`, `.../settings.json`. For each thread in the note's root cause + "at stake" / "next action", ask: *is there a config change that would protect this as a standing guardrail?* Examples of shapes (not a menu — fit the note):
- A CLAUDE.md rule (e.g. "explain the code you ship so I retain understanding before it merges").
- A skill/command that enforces a habit (a pre-ship comprehension gate, an AI-free step).
- A hook (automated before/after behavior) — a `spec.Hook` in `clanker/config`.
- Sometimes the right move is *removing* a rule that's feeding the root cause.

Reject changes that just add more AI mediation to a root cause that's *about* too much AI mediation. Name that tension if it comes up.

## 3. Propose

Present each candidate as: **what** (concrete diff / file), **why** (which thread it protects), **cost** (what it constrains). Then ask me which to apply (AskUserQuestion, multi-select). Apply nothing un-approved.

## 4. Apply

Config is single-sourced in `~/.dotfiles/clanker/config/` and generated per-target. Edit the SOURCE — never a generated file under `claude/.claude/**` or `opencode/.config/opencode/**`:
- **Rules (CLAUDE.md/AGENTS.md) / commands / prompts / hooks / tools:** edit the relevant file under `clanker/config/` (`bodies/`, the spec in `config.go`, `hooks/`, `tools/`), then run `make gen` from `clanker/` to regenerate both trees.
- **Skills:** commit in the `clanker/skills` submodule, bump the single pointer.

Do NOT commit unless I ask. End with: the files changed, and the one-line root cause they trace back to.
