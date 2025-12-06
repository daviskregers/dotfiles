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

**CRITICAL: Start with stubs, build incrementally.**

**First implementation should be a STUB:**

When creating a new handler/function, the FIRST implementation should be the simplest thing that makes the test pass:

```typescript
// ✅ GOOD - First implementation (stub)
export const handle = responseHandler(async (_event) => {
  throw new EntityNotFoundError("Report not found");
});

// ❌ BAD - First implementation (complete solution)
export const handle = responseHandler(async (event) => {
  const { id } = schema.parse(event.pathParameters);
  const report = await getReport(id);
  return ok(report);
});
```

**Then add ONE behaviour at a time:**

- Test 2: Validate parameters → Add ONLY parameter validation
- Test 3: Retrieve data → Add ONLY data retrieval
- Test 4: Transform response → Add ONLY transformation

**Good approach:**

1. Break feature into 3-5 small, testable increments
2. For each increment: RED → GREEN → REFACTOR
3. Each test should verify ONE behaviour or scenario
4. Build complexity gradually, test by test
5. **Start with stubs, add real logic incrementally**

**Bad approach:**

- ❌ Write one test covering entire feature
- ❌ Implement everything before testing
- ❌ Make huge leaps between tests
- ❌ **Implement complete solution on first test**
- ❌ **Jump straight to "real" implementation instead of stub**

**Example - Adding GET /report/{id} endpoint:**

**❌ Bad (one big leap):**

- Test 1: "Handler returns 404 for non-existent report"
- Implementation: Complete handler with validation + getReport() + response ❌
- Test 2: "Handler returns report data"
- Test passes immediately (already implemented) ❌

**✅ Good (small steps with stubs first):**

- Step 1: Test "Handler exists and returns 404"
  - Implementation: Stub that throws EntityNotFoundError
  - ✅ Test passes
- Step 2: Test "Handler validates path parameters"
  - Implementation: Add ONLY Zod validation for params
  - ✅ Test passes
- Step 3: Test "Handler retrieves report from repository"
  - Implementation: Add ONLY getReport() call
  - ✅ Test passes
- Step 4: Test "Handler returns proper response format"
  - Implementation: Add ONLY ok() response wrapper
  - ✅ Test passes

## Verification Requirements

Every implementation must show proof of TDD cycle:

1. **RED proof** - Test output showing meaningful failure
2. **GREEN proof** - Test output showing all tests pass
3. **REFACTOR proof** - Linter output showing code quality

**No proof = incomplete implementation.**

## Test Assertion Standards

**CRITICAL: Always use exact assertions, never partial matches.**

**✅ CORRECT - Exact assertions:**

```typescript
assertBadRequest(await makeRequest(TOKEN.SUPER_ADMIN, {}), {
  fieldErrors: {
    report_id: ["Required"],
  },
  formErrors: [],
});
```

**❌ WRONG - Partial matches:**

```typescript
assertBadRequest(await makeRequest(TOKEN.SUPER_ADMIN, {}), {
  fieldErrors: {
    report_id: expect.arrayContaining([expect.stringContaining("Required")]),
  },
  formErrors: [],
});
```

**Why exact assertions matter:**

- Catches unexpected changes in error messages
- Documents exact API contract
- Fails fast when behaviour changes
- No surprises for API consumers
- Makes tests more maintainable

**When testing API responses:**

- Assert complete response structure
- Use exact error messages
- Don't use `expect.objectContaining()` or similar matchers
- Don't use `expect.stringContaining()` for error messages
- Know the exact response, test the exact response

## Test Isolation and Mocking Standards

**CRITICAL: Mock external API calls, but infrastructure (DB, queues, file systems) can be real.**

**What to mock in unit tests:**

- ✅ **ALWAYS mock: External API calls** (HTTP to other services, third-party APIs)
- ❌ **Don't mock: Infrastructure** (databases, SQS queues, S3, local file systems)

**Rationale:**

- **External APIs**: Unpredictable, slow, require network, can fail, may cost money
- **Infrastructure**: Part of our system, fast in test environments, deterministic, testable

**Unit tests MUST:**

- Mock all external API dependencies (HTTP calls to other services)
- Test business logic in isolation from external systems
- Run fast (milliseconds to seconds)
- Be deterministic (same input always produces same output)
- Not depend on external services being available

**Unit tests CAN:**

- Use real databases (with test fixtures/migrations)
- Send messages to real SQS queues (LocalStack or test queues)
- Write to real file systems (test directories)
- Use real S3 buckets (LocalStack or test buckets)

**Integration/E2E tests MAY:**

- Make actual external API calls
- Test full system integration
- Run slower
- Require all services being available

### Testing Infrastructure Operations

**CRITICAL: When using real infrastructure (SQS, S3, DB), don't write tests that can't verify the outcome.**

**Infrastructure operations that are hard to unit test:**

- **SQS message sending** - Can't easily verify message was sent without polling queue
- **S3 file writes** - Can't verify file exists without reading from S3
- **Async processing** - Can't verify completion in same test execution

**Guideline:**

- ✅ **DO**: Test that handler returns success (201/200) after calling infrastructure
- ✅ **DO**: Write integration/E2E tests that verify end-to-end outcomes
- ❌ **DON'T**: Write unit tests that claim to verify infrastructure but don't actually check anything

**Example - SQS message sending:**

```typescript
// ✅ CORRECT - Simple success test
test("handler returns 201 after queueing job", async () => {
  mockGetReport.mockResolvedValue({ id: "123", periodId: 456 });

  const response = await callHandler({ report_id: "123" });

  expect(response.statusCode).toBe(201);
  // Note: We're NOT verifying the SQS message - that requires E2E test
});

// ❌ WRONG - Test that doesn't verify anything
test("sends SQS message with report data", async () => {
  mockGetReport.mockResolvedValue({ id: "123", periodId: 456 });

  const response = await callHandler({ report_id: "123" });

  expect(response.statusCode).toBe(201);
  // This test claims to verify SQS but doesn't check the queue at all
  // It just verifies the endpoint returns 201, which it already did before adding SQS
});
```

**When to use E2E tests instead:**

- Verifying SQS message contents → E2E test that polls queue
- Verifying S3 file creation → E2E test that checks S3
- Verifying Glue job execution → E2E test that waits for job completion
- Verifying database writes → Can do in unit test by querying DB after operation

**Mocking patterns for external APIs:**

**✅ CORRECT - Mock external API repository calls:**

```typescript
// Mock repository function that makes HTTP calls to external service
jest.mock("../../src/repositories/report", () => ({
  getReport: jest.fn(),
}));

// In test
import { getReport } from "../../src/repositories/report";
const mockGetReport = getReport as jest.MockedFunction<typeof getReport>;

test("fetches report from external service", async () => {
  mockGetReport.mockResolvedValue({ id: "123", periodId: 456 });
  // ... test handler that uses getReport (no actual HTTP call)
});
```

**✅ CORRECT - Use real infrastructure, test success response:**

```typescript
// Handler calls sendSqsMessage (real infrastructure)
test("handler queues job successfully", async () => {
  mockGetReport.mockResolvedValue({ id: "123", periodId: 456 });

  const response = await callHandler({ report_id: "123" });

  expect(response.statusCode).toBe(201);
  // E2E test would poll SQS queue to verify message
});
```

**❌ WRONG - Making actual HTTP calls to external services in unit tests:**

```typescript
test("fetches report", async () => {
  // This makes real HTTP call to external API - WRONG for unit test
  const result = await handle(event);
});
```

**❌ WRONG - Tests that claim to verify infrastructure but don't:**

```typescript
test("sends correct SQS message", async () => {
  // Claims to test SQS message but doesn't verify queue contents
  const response = await callHandler({ report_id: "123" });
  expect(response.statusCode).toBe(201); // Only tests HTTP response
});
```

**Architectural pattern:**

1. **Handlers** - Coordinate between repositories and business logic
2. **Repositories** - Encapsulate external calls (HTTP to external APIs, infrastructure)
3. **Unit Tests** - Mock external API repositories, use real infrastructure, test handler logic
4. **E2E Tests** - Verify end-to-end outcomes (queue messages, file creation, job completion)

**Benefits:**

- Tests run fast
- No flaky tests from network issues or external API changes
- Tests work offline (no external service dependencies)
- Clear separation of concerns
- Easy to test error scenarios (mock error responses)
- Infrastructure remains testable and realistic
- E2E tests verify actual system behavior

## Common Violations

**NEVER do:**

- Write implementation before writing test
- Skip RED phase (not verifying test fails)
- Say "now write the test" after implementing
- Claim "done" without showing test output
- Write one giant test for entire feature
- Make large leaps without intermediate tests
- **Implement complete solution on first test (start with stub!)**
- **Add multiple behaviours in one implementation step**
- **Skip from stub directly to full implementation**

**ALWAYS do:**

- Break work into small, testable increments
- Write test FIRST for each increment
- Run test to see it FAIL
- **Start with simplest stub that makes test pass**
- Implement minimum code for that step (ONE behaviour only)
- Run test to see it PASS
- Run linter for quality
- Repeat for next increment (add ONE more behaviour)
- **Build incrementally: stub → validate → retrieve → transform**

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
