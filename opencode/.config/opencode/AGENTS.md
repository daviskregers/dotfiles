# OpenCode Agents - Global Rules

This file defines global rules that apply to ALL agents in this configuration.

## Global Rules

All agents must follow these rules from `rules/`:

- **[Signal-to-Noise Ratio](rules/signal-to-noise.md)** - Maximize signal, minimize noise in all LLM-consumed content
- **[Test-Driven Development](rules/tdd-first.md)** - Tests come FIRST, not last. RED → GREEN → REFACTOR for all new functionality

## Adding New Global Rules

When adding a new global rule:

1. Create a new file in `rules/` directory
2. Keep it focused on ONE concept
3. Keep it under 100 lines
4. Add a reference here with brief description
5. Update README.md if it affects agent behavior

## Rule Priority

1. **Global rules** (this file) - Apply to all agents
2. **Agent-specific prompts** (`prompts/*.md`) - Apply to specific agent
3. **Project context** (repository `CLAUDE.md` files) - Apply to specific project

When rules conflict, more specific rules take precedence.
