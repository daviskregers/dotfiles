# OpenCode Agents Configuration

This directory contains a comprehensive OpenCode agent configuration converted from Claude rules, with all agents customized to follow your engineering standards.

## Agent Architecture

### Primary Agents (3) - Fully Custom

#### 1. **teacher** (Default)
- **Purpose**: Teaching-focused guide that prioritizes learning through guidance
- **Tools**: Read-only (glob, grep, read, webfetch)
- **Temperature**: 0.1
- **Use**: Default agent for learning and guidance
- **Philosophy**: Challenge assumptions, teach fundamentals, guide don't implement
- **Subagents**: All 9 specialized subagents (full analytical capability)

#### 2. **plan**
- **Purpose**: Analysis and planning agent for thinking before implementing
- **Tools**: Read-only (glob, grep, read, webfetch)
- **Temperature**: 0.15
- **Use**: When you need to analyze and plan before coding
- **Philosophy**: Present options with trade-offs, consider architecture, research best practices
- **Subagents**: All 9 specialized subagents (full analytical capability)

#### 3. **code**
- **Purpose**: Full-access implementation agent with quality standards
- **Tools**: Full access (write, edit, bash with "ask" permission)
- **Temperature**: 0.2
- **Use**: When you want actual code implementation
- **Philosophy**: Quality-focused implementation following your engineering rules
- **Subagents**: 5 implementation-focused subagents (tactical, not strategic)
  - @security, @tester, @typescript-advisor, @logging-advisor, @ops-guide

**Switch Between**: Press Tab to cycle through teacher → plan → code

### Specialized Subagents (9)

#### Strategic Subagents (Planning/Analysis - teacher/plan only)

**4. architect** - Architecture, dependency flow, DDD boundaries, layering violations
- Use before coding to decide architectural approach
- Temperature: 0.05

**5. performance** - Algorithmic efficiency, N+1 queries, race conditions
- Use before coding to choose optimal algorithms
- Temperature: 0.1

**6. design-reviewer** - Design patterns, SOLID principles, code smells
- Use before coding to select appropriate patterns
- Temperature: 0.1

#### Tactical Subagents (Implementation - available to code agent)

**7. security** - Security vulnerabilities, injection attacks, OWASP Top 10
- Use during coding to validate for vulnerabilities
- Temperature: 0.05

**8. tester** - TDD practices, test coverage, mocking philosophy
- Use during coding for immediate testing guidance
- Temperature: 0.1

**9. typescript-advisor** - TypeScript/JavaScript patterns, configuration handling
- Use during coding for language-specific help
- Temperature: 0.1

**10. logging-advisor** - Log levels, security, structured logging
- Use during coding for logging decisions
- Temperature: 0.1

**11. ops-guide** - Operations observability, progress indicators
- Use during coding for script visibility
- Temperature: 0.1

#### Universal Subagent (Available to all)

**12. docs-reviewer** - Documentation efficiency, context cost
- Use anytime for documentation review
- Temperature: 0.1

## Usage

### Three-Mode Workflow

**1. Teacher Mode (Default)** - Learning & Guidance
```
You: How should I structure this authentication system?
Teacher: [Provides guidance, may invoke @architect and @security]
Teacher: Here's the approach... would you like to try implementing it?
```

**2. Plan Mode** - Strategic Planning
```
You: [Press Tab to switch to plan]
You: What are my options for implementing caching?
Plan: [Analyzes with @architect, @performance, @design-reviewer]
Plan: Here are 3 approaches with trade-offs...
```

**3. Code Mode** - Implementation
```
You: [Press Tab to switch to code]
You: Implement the Redis caching approach
Code: [Writes code, may invoke @security, @tester]
Code: @security check this for vulnerabilities
```

### Subagent Access by Agent

| Subagent | Teacher | Plan | Code | Purpose |
|----------|---------|------|------|---------|
| @architect | ✅ | ✅ | ❌ | Strategic: Decide architecture before coding |
| @performance | ✅ | ✅ | ❌ | Strategic: Choose algorithms before coding |
| @design-reviewer | ✅ | ✅ | ❌ | Strategic: Select patterns before coding |
| @security | ✅ | ✅ | ✅ | Tactical: Validate code for vulnerabilities |
| @tester | ✅ | ✅ | ✅ | Tactical: Testing guidance during implementation |
| @typescript-advisor | ✅ | ✅ | ✅ | Tactical: Language-specific help while coding |
| @logging-advisor | ✅ | ✅ | ✅ | Tactical: Logging decisions during coding |
| @ops-guide | ✅ | ✅ | ✅ | Tactical: Script visibility while implementing |
| @docs-reviewer | ✅ | ✅ | ✅ | Universal: Documentation review anytime |

### Manual Subagent Invocation

**From teacher/plan (strategic analysis):**
```
@architect review this architecture
@performance analyze algorithm choices
@design-reviewer suggest patterns
@security check for vulnerabilities
@tester plan testing strategy
```

**From code (tactical implementation):**
```
@security validate this code
@tester how do I test this function?
@typescript-advisor is this pattern correct?
@logging-advisor what log level here?
@ops-guide should this show progress?
```

## Philosophy

This configuration embodies a **teaching-first** approach with clear separation between strategic and tactical decisions:

1. **Guidance Over Implementation**: Learn by doing (teacher mode)
2. **Think Before Coding**: Strategic planning with architecture/performance/patterns (plan mode)
3. **Quality Implementation**: Tactical execution with security/testing/language help (code mode)
4. **Challenge & Teach**: Facts over validation, teach fundamentals
5. **Substantive Focus**: Architecture → Performance → Design → Security
6. **Separation of Concerns**: Strategic decisions (plan) vs Tactical execution (code)

## Files

```
opencode/
├── .config/opencode/
│   ├── opencode.json           # Main configuration
│   ├── README.md               # This file
│   └── prompts/                # Agent prompt files
│       ├── teacher.md          # Teaching/guidance agent (all subagents)
│       ├── plan.md             # Planning/analysis agent (all subagents)
│       ├── code.md             # Implementation agent (5 tactical subagents)
│       ├── architect.md        # Architecture reviews (strategic)
│       ├── performance.md      # Performance analysis (strategic)
│       ├── design-reviewer.md  # Design patterns (strategic)
│       ├── security.md         # Security vulnerabilities (tactical)
│       ├── tester.md           # TDD guidance (tactical)
│       ├── typescript-advisor.md # TypeScript guidance (tactical)
│       ├── logging-advisor.md  # Logging standards (tactical)
│       ├── ops-guide.md        # Operations observability (tactical)
│       └── docs-reviewer.md    # Documentation efficiency (universal)
```

## Conversion from Claude Rules

This configuration was converted from Claude rules in `~/.dotfiles/claude/.claude/rules/`:
- `interaction.md` + `general.md` → `teacher.md`
- `general.md` (analysis priority) → `plan.md`
- `general.md` (code standards) → `code.md`
- `architecture-ddd.md` → `architect.md` (strategic)
- `performance.md` → `performance.md` (strategic)
- `design-patterns.md` → `design-reviewer.md` (strategic)
- `security.md` → `security.md` (tactical)
- `testing.md` → `tester.md` (tactical)
- `languages/typescript.md` → `typescript-advisor.md` (tactical)
- `documentation.md` → `docs-reviewer.md` (universal)
- `logging.md` → `logging-advisor.md` (tactical)
- `operations.md` → `ops-guide.md` (tactical)

All agents maintain the principles and priorities from the original rules.

## Why Separate Strategic vs Tactical Subagents?

**The Problem:**
- Mixing planning and implementation leads to "analysis paralysis" during coding
- Code agent shouldn't second-guess architectural decisions mid-implementation

**Our Solution:**
- **Strategic subagents** (@architect, @performance, @design-reviewer): Make decisions *before* coding
- **Tactical subagents** (@security, @tester, @typescript-advisor, etc.): Help *during* implementation
- Clean workflow: Plan with strategy → Implement with tactics

This gives you:
- ✅ **Clear decision phases** - Plan architecture, then implement
- ✅ **Focused implementation** - Code agent executes without overthinking
- ✅ **Tactical support** - Security, testing, language help during coding
- ✅ **Prevents rework** - Strategic decisions made upfront
- ✅ **Better separation** - Analysis ≠ Implementation
