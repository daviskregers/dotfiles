# Design Patterns & Maintainability

**Priority: #3 - Focus on substantive engineering issues**

## When Patterns Help
- **Strategy Pattern**: Multiple algorithms/behaviors selectable at runtime
  - Example: Different payment processors, sorting algorithms, validation strategies
- **Factory Pattern**: Complex object creation logic or need for centralization
  - Example: Creating different types of database connections, HTTP clients
- **Observer Pattern**: Multiple components reacting to state changes
  - Example: Event systems, reactive data flows, pub/sub
- **Decorator Pattern**: Adding behavior without modifying existing code
  - Example: Adding logging, caching, retry logic to existing functions
- **Repository Pattern**: Abstracting data access layer
  - Example: Swapping databases, testing with mocks, DDD persistence
- **Dependency Injection**: Loose coupling and testability
  - Example: Service configuration, testing with mocks
- **Command Pattern**: Encapsulating operations for undo/redo, queueing
- **Saga Pattern**: Managing distributed transactions and compensation

---

## When Patterns Hurt (Anti-Patterns)
- **Premature abstraction**: Creating factories/strategies for one implementation
- **God objects**: Classes/modules that know/do too much
- **Spaghetti code**: No clear structure, everything depends on everything
- **Tight coupling**: Direct dependencies making code rigid and hard to test
- **Magic numbers/strings**: Hardcoded values without named constants
- **Shotgun surgery**: One change requires modifications in many places
- **Copy-paste programming**: Duplicated logic instead of proper abstraction
- **Golden hammer**: Using same pattern for every problem
- **Cargo cult programming**: Using patterns without understanding why
- **Big ball of mud**: No discernible architecture

---

## SOLID Principles

### Single Responsibility Principle
- Each module/class should have one reason to change
- ❌ A class handling HTTP requests, database access, and email sending
- ✅ Separate classes for each concern

### Open/Closed Principle
- Open for extension, closed for modification
- ❌ Adding if/else branches for each new type
- ✅ Using interfaces/abstract classes for extensibility

### Liskov Substitution Principle
- Subtypes should be substitutable for base types without breaking behavior
- ❌ Overriding methods to throw "not implemented"
- ❌ Subclass strengthening preconditions or weakening postconditions
- ✅ Proper inheritance hierarchies where subtypes truly extend behavior

### Interface Segregation Principle
- Clients shouldn't depend on interfaces they don't use
- ❌ One massive interface with 20 methods when clients need 2-3
- ✅ Small, focused interfaces (role interfaces)

### Dependency Inversion Principle
- Depend on abstractions, not concretions
- ❌ Directly instantiating dependencies in constructors
- ✅ Accepting interfaces/abstractions, injecting concrete implementations

---

## Code Smells (Maintainability Issues)

### Duplication - Rule of Three
**Principle**: First occurrence = write it. Second occurrence = tolerate it. Third occurrence = refactor it.

```typescript
// First occurrence - write it
function validateUserEmail(email: string) {
  if (!email.includes('@')) throw new Error('Invalid email');
  if (email.length > 255) throw new Error('Email too long');
}

// Second occurrence - tolerate duplication
function validateAdminEmail(email: string) {
  if (!email.includes('@')) throw new Error('Invalid email');
  if (email.length > 255) throw new Error('Email too long');
}

// Third occurrence - time to refactor!
function validateSupportEmail(email: string) {
  if (!email.includes('@')) throw new Error('Invalid email');
  if (email.length > 255) throw new Error('Email too long');
}

// ✅ Refactored - extract shared logic
function validateEmail(email: string) {
  if (!email.includes('@')) throw new Error('Invalid email');
  if (email.length > 255) throw new Error('Email too long');
}

function validateUserEmail(email: string) { validateEmail(email); }
function validateAdminEmail(email: string) { validateEmail(email); }
function validateSupportEmail(email: string) { validateEmail(email); }
```

**When to extract duplication:**
- Same logic repeated **3+ times** → extract to function/utility
- Similar code blocks with minor variations → parameterize the differences
- Repeated validation logic → extract to shared validator
- Duplicated transformation logic → extract to utility function

**When NOT to extract (acceptable duplication):**
- Two occurrences of simple logic (wait for third)
- Coincidental similarity (logic happens to look similar but represents different concepts)
- Different rate of change (duplicated code evolves independently for different reasons)

### Other Code Smells
- **Long methods/functions**: Hard to understand, test, and maintain (>20-30 lines is suspicious)
- **Long parameter lists**: Consider objects, builder pattern, or method extraction
- **Feature envy**: Method more interested in other class's data than its own
- **Data clumps**: Same group of parameters appearing together (create value object)
- **Primitive obsession**: Using primitives instead of value objects (e.g., string for email/phone)
- **Switch statements on type**: Consider polymorphism or strategy pattern
- **Lazy class**: Class that doesn't do enough to justify its existence
- **Speculative generality**: Over-engineering for hypothetical future needs
- **Dead code**: Unused code that should be removed
- **Magic numbers/strings**: Hardcoded values without explanation (use named constants)

---

## Complexity Metrics
- **Cyclomatic complexity**: Too many branches/paths through code
- **Nesting depth**: Deep nesting (>3-4 levels) indicates complex logic
- **Duplication**: Copy-pasted code that indicates missing abstraction
- **Module coupling**: Too many dependencies between modules
