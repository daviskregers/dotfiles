# Signal-to-Noise Ratio - Global Rule

**CRITICAL: Tokens are expensive. Every word must earn its place.**

## Core Principle

When creating or modifying content that will be read by LLMs (agent prompts, rules, context files, documentation):

**Maximize signal, minimize noise.**

## What is Noise?

- Redundant explanations of the same concept
- Overly defensive rules ("NEVER do X" repeated multiple times)
- Verbose examples when concise ones suffice
- Generic advice that applies everywhere (not specific to the context)
- Excessive formatting or visual fluff
- Apologetic or validating language
- Multiple ways of saying the same thing

## What is Signal?

- Actionable instructions
- Concrete examples
- Specific patterns to follow
- Clear decision criteria
- Unique information not stated elsewhere
- Templates and structures to use

## Guidelines

### Before Writing

Ask: "Is this the most concise way to convey this information?"

### When Editing

1. **Remove redundancy** - If it's said once clearly, don't repeat it
2. **Consolidate sections** - Merge overlapping content
3. **Cut generic advice** - Remove platitudes and obvious statements
4. **Simplify examples** - Use minimal examples that demonstrate the point
5. **Remove defensive language** - State what to do, not what not to do (unless critical)

### Target Metrics

- **Agent prompts**: Aim for <200 lines for primary agents, <150 for subagents
- **Rule files**: One concept per file, <100 lines
- **Context files**: Dense information, minimal prose

### Red Flags

If you see these patterns, you probably have noise:

- Multiple sections covering the same topic
- Lists of "don't do X" without actionable alternatives
- Explanations of why rules exist (unless teaching)
- Examples showing both good and bad (usually one is enough)
- Sections titled "Important", "Critical", "Remember" (the content should speak for itself)

## Application

This rule applies to:

- ✅ Agent prompt files (`prompts/*.md`)
- ✅ Rule files (`rules/*.md`)
- ✅ Project context files (`CLAUDE.md`, `AGENTS.md`, etc.)
- ✅ Documentation meant for LLM consumption
- ❌ User-facing documentation (can be more verbose for clarity)
- ❌ Teaching materials where explanation aids learning

## Example: Before and After

### ❌ Noisy (120 words)

```
## Important: Always Validate Types

It is extremely important that you always validate types before using them.
Never use types that don't exist. This is critical because if you reference
non-existent types, the code will fail. Always search the codebase first to
confirm the type exists. This is a mandatory requirement. You must verify
that imports are available. Never assume a type exists without checking.
This rule is very important and should never be violated. Remember to always
validate types before suggesting code changes. This prevents errors and
ensures code quality.
```

### ✅ Signal (15 words)

```
## Type Validation

Before suggesting code: verify types/functions/imports exist in codebase via search.
```

## Enforcement

When reviewing agent prompts or rules:

1. Count lines - is it within target metrics?
2. Scan for redundancy - is anything repeated?
3. Check for generic advice - is it specific to this context?
4. Verify actionability - can someone follow this directly?

**If it doesn't pass these checks, refactor for higher signal-to-noise ratio.**
