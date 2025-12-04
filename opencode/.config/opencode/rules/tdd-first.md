# Test-Driven Development (TDD) - Global Rule

**CRITICAL: Tests come FIRST, not last. Small steps, one test at a time.**

## Core Principle

When implementing new functionality or fixing bugs:

**Break into SMALL steps. For each step: write test FIRST (RED), implement SECOND (GREEN), refactor THIRD.**

## The TDD Cycle

**For each small increment:**

1. **RED** - Write failing test that describes desired behaviour for THIS step
2. **GREEN** - Write minimum code to make test pass
3. **REFACTOR** - Clean up code while keeping tests green
4. **REPEAT** - Move to next small increment

**CRITICAL: One small step at a time, not huge leaps.**

## When TDD Applies

**MANDATORY for:**

- New features or functionality
- New API endpoints or handlers
- New business logic or algorithms
- Bug fixes (test reproduces bug first)
- Repository functions (database operations)
- Service layer functions (business logic)

**NOT required for:**

- Trivial changes (typo fixes, formatting)
- Configuration updates (environment variables)
- Documentation changes
- Refactoring with existing test coverage

## Pre-Implementation Checklist

**Before starting ANY feature, break it into small steps:**

- [ ] Have I identified the smallest testable increment?
- [ ] Have I written a test for JUST this small step?
- [ ] Have I run the test to verify it fails?
- [ ] Does the failure message clearly show what's missing?

**If ANY answer is NO → STOP. Break it down smaller or write/run the test first.**

## Small Incremental Steps

**CRITICAL: Don't write one giant test for an entire feature.**

**Good approach:**

1. Break feature into 3-5 small, testable increments
2. For each increment: RED → GREEN → REFACTOR
3. Each test should verify ONE behaviour or scenario
4. Build complexity gradually, test by test

**Bad approach:**

- ❌ Write one test covering entire feature
- ❌ Implement everything before testing
- ❌ Make huge leaps between tests

**Example - Adding report status update:**

**❌ Bad (one big leap):**

- Test: "Report creation with warehouse failure updates status to FAILED"
- Implementation: Create report + trigger warehouse + handle errors + update status

**✅ Good (small steps):**

- Step 1: Test "updateReportStatus updates status in database" → Implement
- Step 2: Test "Report handler catches warehouse errors" → Implement
- Step 3: Test "Handler sets FAILED status on error" → Implement

## Verification Requirements

Every implementation must show proof of TDD cycle:

1. **RED proof** - Test output showing meaningful failure
2. **GREEN proof** - Test output showing all tests pass
3. **REFACTOR proof** - Linter output showing code quality

**No proof = incomplete implementation.**

## Common Violations

**NEVER do:**

- Write implementation before writing test
- Skip RED phase (not verifying test fails)
- Say "now write the test" after implementing
- Claim "done" without showing test output
- Write one giant test for entire feature
- Make large leaps without intermediate tests

**ALWAYS do:**

- Break work into small, testable increments
- Write test FIRST for each increment
- Run test to see it FAIL
- Implement minimum code for that step
- Run test to see it PASS
- Run linter for quality
- Repeat for next increment

## Decision Tree

```
Are you about to write implementation code?
├─ YES → Have I broken this into small steps?
│         ├─ NO → STOP. Break into 3-5 small increments first.
│         └─ YES → Has test been written for THIS step?
│                   ├─ NO → STOP. Write test for this increment.
│                   └─ YES → Has test been run and verified to fail?
│                             ├─ NO → STOP. Run test and verify RED.
│                             └─ YES → Proceed with minimum implementation.
│                                      After GREEN, repeat for next step.
└─ NO → Is this a trivial change (typo/config/docs)?
          ├─ YES → Proceed without TDD.
          └─ NO → You need a test. Return to start.
```

## Application

This rule applies to:

- ✅ All implementation agents
- ✅ All code changes introducing new behaviour
- ✅ All bug fixes
- ❌ Documentation-only changes
- ❌ Configuration-only changes
- ❌ Refactoring with existing tests
