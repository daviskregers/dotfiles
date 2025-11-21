# Testing & Test-Driven Development

## Safe Refactoring - Tests First

**CRITICAL RULE: Never refactor code without tests.**

### Refactoring Prerequisites

Before any refactoring:

1. **Existing functionality MUST be covered by tests**
   - If tests don't exist, write them first
   - Tests should verify current behavior (even if imperfect)
   - Tests act as safety net to ensure refactoring doesn't change behavior

2. **All tests must be passing**
   - Green test suite before starting refactoring
   - Any failures must be fixed first

3. **Tests must remain passing throughout refactoring**
   - If tests fail, you've changed behavior (not just refactored)
   - Only test assertions should change if you're intentionally fixing bugs

### Safe Refactoring Process

```
1. Write tests for existing behavior (if missing)
2. Ensure all tests pass (green)
3. Refactor code (change structure, not behavior)
4. Run tests - should still pass (green)
5. If tests fail → revert and try different approach
```

### Examples

#### ❌ Unsafe Refactoring - No Tests
```typescript
// User asks: "Can you refactor this function to be more readable?"
function processOrder(order) {
  // Complex logic...
}

// ❌ DON'T refactor without tests
// Assistant should respond:
// "Before refactoring, we need tests to ensure behavior doesn't change.
//  Let me help you write tests for the current behavior first."
```

#### ✅ Safe Refactoring - Test Coverage First
```typescript
// Step 1: Write tests for existing behavior
describe('processOrder', () => {
  it('should calculate total with tax', () => {
    const order = { items: [{ price: 100 }], taxRate: 0.1 };
    expect(processOrder(order).total).toBe(110);
  });

  it('should apply discount before tax', () => {
    const order = { items: [{ price: 100 }], discount: 10, taxRate: 0.1 };
    expect(processOrder(order).total).toBe(99);
  });
});

// Step 2: Verify tests pass with current implementation ✅

// Step 3: Now refactor safely
function processOrder(order) {
  const subtotal = calculateSubtotal(order.items);
  const afterDiscount = applyDiscount(subtotal, order.discount);
  const total = addTax(afterDiscount, order.taxRate);
  return { total };
}

// Step 4: Tests still pass ✅ - refactoring successful
```

---

## Test-Driven Development (TDD)

### TDD Cycle - Red, Green, Refactor

**Follow this cycle strictly:**

1. **Red** - Write minimum test to fail
2. **Verify** - Ensure test actually fails (don't skip this!)
3. **Green** - Write minimum code to make test pass
4. **Refactor** - Improve code while keeping tests green

### TDD Process

#### Step 1: Red - Write Failing Test
Write the **minimum** test that expresses the requirement:

```typescript
// ✅ Minimum failing test
describe('validateEmail', () => {
  it('should reject email without @', () => {
    expect(() => validateEmail('invalid')).toThrow('Invalid email');
  });
});

// Run test → ❌ FAILS (function doesn't exist yet)
```

**Why verify failure:**
- Ensures test is actually running
- Confirms test will catch regressions
- Avoids false positives (tests that always pass)

#### Step 2: Green - Make It Pass
Write the **minimum** code to pass the test:

```typescript
// ✅ Minimum implementation
function validateEmail(email: string) {
  if (!email.includes('@')) {
    throw new Error('Invalid email');
  }
}

// Run test → ✅ PASSES
```

**Don't over-implement:**
```typescript
// ❌ Too much code - not test-driven
function validateEmail(email: string) {
  // Writing email regex, length checks, TLD validation
  // when test only requires @ check
}
```

#### Step 3: Refactor - Improve Code
Now improve while keeping tests green:

```typescript
// Test is green, so we can safely refactor
function validateEmail(email: string) {
  const hasAtSymbol = email.includes('@');
  if (!hasAtSymbol) {
    throw new Error('Invalid email');
  }
}

// Run test → ✅ STILL PASSES
```

#### Step 4: Add Next Test (Red Again)
```typescript
// Next requirement - add another test
it('should reject email without domain', () => {
  expect(() => validateEmail('user@')).toThrow('Invalid email');
});

// Run test → ❌ FAILS
```

#### Step 5: Make It Pass (Green Again)
```typescript
function validateEmail(email: string) {
  if (!email.includes('@')) {
    throw new Error('Invalid email');
  }

  const [, domain] = email.split('@');
  if (!domain) {
    throw new Error('Invalid email');
  }
}

// Run test → ✅ PASSES
```

### TDD Benefits

- **Safety**: Tests catch regressions immediately
- **Design**: Writing tests first leads to better API design
- **Coverage**: 100% coverage by default (every line has a test)
- **Documentation**: Tests document expected behavior
- **Confidence**: Refactor freely knowing tests will catch breaks

---

## When to Write Tests

### Always Write Tests For:
- **New features**: TDD from the start
- **Bug fixes**: Write failing test that reproduces bug, then fix
- **Refactoring**: Write tests for existing behavior first
- **Public APIs**: All public interfaces must be tested
- **Business logic**: Critical business rules need comprehensive tests
- **Complex algorithms**: Edge cases and corner cases

### Consider Skipping Tests For:
- **Throwaway prototypes**: If you're exploring and will delete code
- **Generated code**: If code is auto-generated from schemas
- **Configuration files**: Static configuration (but test validation logic)

---

## Mocking Philosophy

**Prefer real implementations over mocks.**

### When to Use Real Implementations

**Default approach** - use real implementations whenever possible:

```typescript
// ✅ Preferred - real database (test DB)
it('should create user', async () => {
  const userId = await userService.create({ name: 'John' });
  const user = await userService.findById(userId);
  expect(user.name).toBe('John');
});

// ✅ Preferred - real service layer
it('should process order', async () => {
  const product = await createTestProduct({ price: 100 });
  const order = await orderService.create({ productId: product.id });
  expect(order.total).toBe(100);
});

// ✅ Preferred - real validation
it('should validate email', () => {
  expect(() => validateEmail('invalid')).toThrow();
  expect(validateEmail('test@example.com')).toBe('test@example.com');
});
```

**Benefits of real implementations:**
- **Tests actual integration** - catches real bugs
- **Tests behavior, not implementation** - can refactor without breaking tests
- **More confidence** - if tests pass, code actually works
- **Simpler tests** - no mock setup/teardown
- **Realistic** - tests how code runs in production

### When Mocks Are Acceptable

**Only mock for third-party integrations** that are:
- External services you don't control
- Expensive or slow (payment gateways, email services)
- Non-deterministic (current time, random IDs)

```typescript
// ✅ Acceptable - third-party payment gateway
it('should process payment', async () => {
  const mockStripe = {
    charges: {
      create: jest.fn().mockResolvedValue({ id: 'ch_123', status: 'succeeded' })
    }
  };

  const result = await processPayment(mockStripe, { amount: 100 });
  expect(result.status).toBe('succeeded');
});

// ✅ Acceptable - external email service
it('should send welcome email', async () => {
  const mockMailer = {
    send: jest.fn().mockResolvedValue({ messageId: 'msg_123' })
  };

  await sendWelcomeEmail(mockMailer, user);
  expect(mockMailer.send).toHaveBeenCalledWith({
    to: user.email,
    subject: 'Welcome'
  });
});

// ✅ Acceptable - time-based logic
it('should check expiration', () => {
  jest.useFakeTimers();
  jest.setSystemTime(new Date('2024-01-01'));

  const token = createToken({ expiresIn: '1d' });
  expect(isExpired(token)).toBe(false);

  jest.setSystemTime(new Date('2024-01-03'));
  expect(isExpired(token)).toBe(true);
});
```

### When NOT to Mock

**Don't mock your own code:**

```typescript
// ❌ Bad - mocking your own database layer
it('should create user', async () => {
  jest.spyOn(db, 'insert').mockResolvedValue({ id: 1 });
  const user = await userService.create({ name: 'John' });
  expect(user.id).toBe(1);
  // This doesn't test if database insertion actually works!
});

// ✅ Good - use real test database
it('should create user', async () => {
  const userId = await userService.create({ name: 'John' });
  const user = await db.select().from(users).where(eq(users.id, userId));
  expect(user.name).toBe('John');
  // Tests actual database integration
});

// ❌ Bad - mocking your own service layer
it('should process order', async () => {
  jest.spyOn(inventoryService, 'checkStock').mockResolvedValue(true);
  await orderService.create({ productId: 1 });
  // Doesn't test if inventory check actually works!
});

// ✅ Good - use real service with test data
it('should process order', async () => {
  await createTestProduct({ id: 1, stock: 10 });
  const order = await orderService.create({ productId: 1 });
  const product = await getProduct(1);
  expect(product.stock).toBe(9);
  // Tests actual inventory integration
});
```

### Test Infrastructure

**Set up proper test infrastructure** instead of mocking:

- **Test database**: Use same database engine with test data
- **Test fixtures**: Reusable test data setup/teardown
- **In-memory alternatives**: Redis → in-memory cache, S3 → local filesystem
- **Test containers**: Docker containers for databases, message queues

```typescript
// ✅ Test setup with real infrastructure
beforeEach(async () => {
  // Clear test database
  await testDb.delete(users);
  await testDb.delete(orders);
});

afterEach(async () => {
  // Cleanup test data
  await testDb.delete(users);
});

it('should create order', async () => {
  const user = await createTestUser({ name: 'John' });
  const order = await orderService.create({ userId: user.id, total: 100 });
  expect(order.userId).toBe(user.id);
});
```

---

## Test Quality Standards

### Good Tests Are:

#### 1. Fast
```typescript
// ✅ Fast - runs in milliseconds
it('should calculate total', () => {
  const result = calculateTotal([10, 20, 30]);
  expect(result).toBe(60);
});

// ❌ Slow - real HTTP calls to external services
it('should fetch user data', async () => {
  const user = await fetch('https://api.example.com/users/1');
  expect(user.name).toBe('John');
});

// ✅ Fast - use real implementations with test database
it('should fetch user data', async () => {
  await testDb.insert(users).values({ id: 1, name: 'John' });
  const user = await fetchUser(1);
  expect(user.name).toBe('John');
});
```

#### 2. Isolated
```typescript
// ❌ Tests depend on each other
describe('UserService', () => {
  let userId;

  it('should create user', async () => {
    userId = await createUser({ name: 'John' });
    expect(userId).toBeDefined();
  });

  it('should update user', async () => {
    // Depends on previous test!
    await updateUser(userId, { name: 'Jane' });
  });
});

// ✅ Tests are independent
describe('UserService', () => {
  it('should create user', async () => {
    const userId = await createUser({ name: 'John' });
    expect(userId).toBeDefined();
  });

  it('should update user', async () => {
    // Setup its own test data
    const userId = await createUser({ name: 'John' });
    await updateUser(userId, { name: 'Jane' });
    const user = await getUser(userId);
    expect(user.name).toBe('Jane');
  });
});
```

#### 3. Deterministic
```typescript
// ❌ Non-deterministic (random, time-based)
it('should generate unique ID', () => {
  const id = generateId();
  expect(id).toBe(12345); // Fails randomly!
});

// ✅ Deterministic (mocked randomness)
it('should generate unique ID', () => {
  jest.spyOn(Math, 'random').mockReturnValue(0.5);
  const id = generateId();
  expect(id).toBe(12345);
});
```

#### 4. Readable
```typescript
// ❌ Unclear what's being tested
it('test1', () => {
  const x = f(1, 2, 3);
  expect(x).toBe(6);
});

// ✅ Clear test name and structure
it('should sum all array elements', () => {
  const sum = sumArray([1, 2, 3]);
  expect(sum).toBe(6);
});
```

#### 5. Test One Thing
```typescript
// ❌ Tests multiple things
it('should handle user operations', async () => {
  await createUser({ name: 'John' });
  await updateUser(1, { name: 'Jane' });
  await deleteUser(1);
  // Which one is being tested?
});

// ✅ One assertion per test
it('should create user', async () => {
  const userId = await createUser({ name: 'John' });
  expect(userId).toBeDefined();
});

it('should update user', async () => {
  const userId = await createUser({ name: 'John' });
  await updateUser(userId, { name: 'Jane' });
  const user = await getUser(userId);
  expect(user.name).toBe('Jane');
});
```

---

## Test Coverage Requirements

### Minimum Coverage
- **Business logic**: 100% coverage (all branches)
- **Public APIs**: 100% coverage
- **Utilities**: 95%+ coverage
- **UI components**: 80%+ coverage (focus on logic, not rendering)

### What to Test
- **Happy path**: Normal operation
- **Edge cases**: Boundary conditions (empty arrays, null, zero, max values)
- **Error cases**: Invalid input, exceptions, timeouts
- **State transitions**: All possible state changes

---

## Red Flags - Unsafe Practices

### ⚠️ Warning Signs:
- **Refactoring without tests**: Will likely break behavior silently
- **Skipping red phase**: Writing code before test fails (can't verify test works)
- **Tests always pass**: Not properly testing behavior
- **Changing tests to match code**: Tests should define behavior, not follow it
- **"I'll add tests later"**: Usually means never

### 🚫 Never Do This:
```typescript
// ❌ Writing implementation first, then tests
function calculateDiscount(price, rate) {
  return price * (1 - rate);
}

// Then writing test
it('should calculate discount', () => {
  expect(calculateDiscount(100, 0.1)).toBe(90);
});
```

### ✅ Always Do This:
```typescript
// ✅ Test first (TDD)
it('should calculate discount', () => {
  expect(calculateDiscount(100, 0.1)).toBe(90);
});
// → ❌ FAILS (function doesn't exist)

// Then implement
function calculateDiscount(price, rate) {
  return price * (1 - rate);
}
// → ✅ PASSES
```

---

## Summary

**Golden Rules:**
1. **No refactoring without tests** - write tests first if missing
2. **Follow TDD cycle** - Red → Verify → Green → Refactor
3. **Always verify tests fail** - don't skip the red phase
4. **Keep tests green** - if refactoring breaks tests, you changed behavior
5. **Test behavior, not implementation** - tests should survive refactoring

**Goal**: Confidence to change code without fear of breaking things.
