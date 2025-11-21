# Architecture & Domain-Driven Design

**Priority: #1 - Focus on substantive engineering issues**

## Dependency Direction (Clean Architecture)

- **Inward-pointing dependencies**: Dependencies should point toward domain/business logic
  - ❌ Core domain depending on infrastructure, UI, or frameworks
  - ✅ Infrastructure and UI depending on domain abstractions
  - Outer layers (UI, infrastructure) depend on inner layers (domain)
  - Inner layers never depend on outer layers
- **Abstractions at boundaries**: Use interfaces/ports to invert dependencies
  - Domain defines interfaces, infrastructure implements them
- **Dependency Inversion Principle**: High-level modules shouldn't depend on low-level modules

---

## Domain-Driven Design Boundaries

### Bounded Contexts
- Each context should have clear boundaries and own its models
  - ❌ Sharing domain entities across contexts (tight coupling)
  - ✅ Each context owns its models, communicate via events/APIs/DTOs
- **Context mapping violations**: Unclear relationships between bounded contexts
  - Look for proper patterns: Shared Kernel, Customer/Supplier, Anti-corruption Layer, Published Language
  - Flag implicit dependencies between contexts

### Aggregate Boundaries
- Don't bypass aggregates to modify internal entities
  - ❌ Directly modifying child entities from outside
  - ❌ Exposing setters that allow invariant violations
  - ✅ All changes go through aggregate root
  - ✅ Aggregate root enforces invariants and business rules
- **Transaction boundaries**: One transaction per aggregate
  - ❌ Transactions spanning multiple aggregates
  - ✅ Use eventual consistency between aggregates

### Domain Logic Leakage
- Business rules should be in domain layer, not scattered
  - ❌ Validation logic in controllers/API layer
  - ❌ Business logic in SQL queries or stored procedures
  - ❌ Domain rules in UI components
  - ❌ Service classes with all the logic (anemic domain)
  - ✅ Domain models enforce their own invariants
  - ✅ Business rules encapsulated in domain entities/value objects
  - ✅ Domain services for logic that doesn't belong to one entity

### Infrastructure Contamination
- Domain shouldn't depend on infrastructure concerns
  - ❌ Domain entities with ORM annotations (JPA, Entity Framework)
  - ❌ Database-specific code in domain layer
  - ❌ HTTP/REST concerns in domain models
  - ❌ Framework-specific attributes in domain
  - ✅ Domain models are persistence-ignorant
  - ✅ Infrastructure layer maps between domain and persistence
  - ✅ Use repository interfaces defined in domain, implemented in infrastructure

### Anemic Domain Models
- Entities should have behavior, not just data
  - ❌ All logic in service classes, entities with only getters/setters
  - ❌ Domain models that are just data bags (DTOs masquerading as entities)
  - ✅ Rich domain models with behavior and business logic
  - ✅ Methods that enforce business rules and maintain invariants
  - ✅ Value objects for domain concepts without identity

---

## Layering Violations

**Typical layers (innermost to outermost):**
- Domain (entities, value objects, domain services, domain events)
- Application (use cases, application services, orchestration)
- Infrastructure (persistence, external services, adapters)
- Presentation (UI, API controllers, views)

**Common violations:**
- UI/Controllers calling repositories directly (bypassing application/domain logic)
- Domain layer depending on framework specifics
- Business logic scattered across layers instead of centralized
- Infrastructure concerns leaking into domain
- Presentation layer doing business logic

### Controller/Service/Repository Pattern (3-Layer)

When using the common 3-layer pattern, watch for these violations:

**Controller Layer (Presentation):**
- ❌ Business logic in controllers (should be in services)
- ❌ Database queries in controllers (should be in repositories)
- ❌ Direct data transformation/validation (should be in services)
- ✅ HTTP concerns only: request/response handling, status codes, headers
- ✅ Delegate to services for business logic
- ✅ Minimal validation (basic type checking), deep validation in services

**Service Layer (Application/Domain):**
- ❌ HTTP concerns in services (status codes, headers - should be in controllers)
- ❌ Database queries in services (should be in repositories)
- ❌ External API calls in services (should be in repositories/adapters)
- ✅ Business logic and orchestration
- ✅ Transaction coordination
- ✅ Business rule enforcement
- ✅ Call repositories for data access

**Repository Layer (Infrastructure):**
- ❌ Business logic in repositories (should be in services)
- ❌ HTTP response formatting (should be in controllers)
- ✅ Database queries and data access
- ✅ External API calls (wrapped in repository interface)
- ✅ Data mapping (database ↔ domain models)
- ✅ Query optimization

---

## Coupling & Module Boundaries

- **Circular dependencies**: Modules depending on each other (prevent proper layering)
- **High coupling**: Changes in one module ripple through many others
- **Poor boundaries**: Unclear separation of concerns between modules
- **God modules**: Modules that know/do too much
- **Feature envy**: Modules more interested in other modules' data than their own

---

## Atomicity & Transaction Patterns

### When Atomicity Is Required

Operations that must complete **all-or-nothing** to maintain system consistency:

#### Database Operations
- Multiple related inserts/updates/deletes
- Operations that must maintain referential integrity
- Balance transfers, inventory adjustments
- **Solution**: Use database transactions

```typescript
// ✅ Atomic database operations
await db.transaction(async (trx) => {
  await trx.update(accounts).set({ balance: sourceBalance - amount }).where(eq(accounts.id, sourceId));
  await trx.update(accounts).set({ balance: targetBalance + amount }).where(eq(accounts.id, targetId));
  await trx.insert(transactions).values({ sourceId, targetId, amount });
});
```

#### File Operations
- Creating multiple related files
- File moves that must be atomic
- Configuration updates across multiple files
- **Solution**: Write to temp location, then atomic rename/move; implement rollback capability

```typescript
// ✅ Atomic file operations with rollback
const tempFile = `${configFile}.tmp`;
await fs.writeFile(tempFile, newConfig);
try {
  await fs.rename(tempFile, configFile);  // Atomic on most filesystems
} catch (error) {
  await fs.unlink(tempFile);  // Rollback
  throw error;
}
```

#### External API Calls
- Multi-step processes with external services
- Payment + fulfillment + notification
- **Solution**: Saga pattern with compensating transactions

```typescript
// ✅ Saga pattern for distributed operations
async function processOrder(order) {
  let paymentId, fulfillmentId;

  try {
    paymentId = await chargePayment(order);
    fulfillmentId = await createFulfillment(order);
    await sendConfirmation(order);
  } catch (error) {
    // Compensating transactions (rollback)
    if (fulfillmentId) await cancelFulfillment(fulfillmentId);
    if (paymentId) await refundPayment(paymentId);
    throw error;
  }
}
```

#### State Changes
- Multiple related state updates that must stay consistent
- Cache + database + search index updates
- **Solution**: Update in transaction or implement eventual consistency with event sourcing

### Red Flags - Missing Atomicity

Watch for these patterns that indicate missing atomicity:

- **Partial failure leaves system inconsistent**
  - Money deducted but order not created
  - User created but email not sent (if email confirmation is required)
  - File uploaded but database record not created

- **No error handling for multi-step operations**
  - First step succeeds, second step fails, no rollback
  - Exception thrown but previous steps not reverted

- **Manual cleanup required after failures**
  - "Run this script to fix inconsistent state"
  - Orphaned records requiring manual deletion

- **Race conditions from split operations**
  - Check balance, then deduct (should be atomic)
  - Read-modify-write without locking

### When NOT to Use Transactions

- **Independent operations**: Don't need atomicity if operations are truly independent
- **Read-only operations**: No consistency concerns
- **Idempotent operations**: Can be safely retried
- **Performance-critical paths**: When eventual consistency is acceptable
