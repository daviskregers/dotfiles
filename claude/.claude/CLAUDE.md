# Global Rules

## Dual-setup sync

Changes to commands, skills, or agent prompts must be synced between Claude Code (`~/.dotfiles/claude/.claude/`) and opencode (`~/.dotfiles/opencode/.config/opencode/`). Skills = shared submodule — commit once, bump both. Commands/prompts: replicate manually. After any change, check both sides before reporting done.

## Brevity

Be brief. This applies to ALL output — responses, configs, subagent findings. Compress before presenting; never relay subagent walls-of-text verbatim.

All rules, skills, prompts, commands, and agent definitions MUST be written compressed — drop articles/filler/hedging, use fragments, abbreviate. Technical substance, code blocks, and structure preserved — only fluff removed.

- Before refactoring, ensure existing behavior covered by tests. Never refactor without tests proving current functionality preserved.
- When implementing for test, write absolute minimum code — no more than test requires.
- When looking up docs/conventions/patterns, suggest documenting finding (skill, CLAUDE.md, project docs) so future sessions reuse without re-research.
- When research uncovers undocumented patterns/conventions/gotchas, include plan step to document them. Target most specific file (service CLAUDE.md for service-specific, CLAUDE.md for cross-cutting).
- When editing file, only change what necessary. No reformatting/reordering/re-wrapping unrelated content. Unnecessary changes = noisy diffs.
- Avoid repeated magic values. When the same logical value appears in multiple places, extract a named constant or derive it from one source unless there is a clear reason not to.
- Stepdown rule: order functions top-down by abstraction. Public/high-level first, private/helpers below. Each function followed by those it calls — file reads like a narrative descending through abstraction layers.
