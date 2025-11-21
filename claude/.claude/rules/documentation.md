# Documentation Standards

## Keep Documentation Efficient

- **Concise with high signal-to-noise ratio**: Every sentence should provide value
- **Minimize context cost**: This applies to AI-assisted development and human readers
- **READMEs should be minimal and actionable**:
  - Essential setup steps
  - Deployment instructions
  - Configuration options
  - Remove "how it works", architecture details, maintenance tips
- **Code should be self-documenting**: Use clear names and structure
- **Goal**: Minimize scrolling and search time to find what's needed

---

## When to Document

- Complex algorithms or non-obvious logic
- Public APIs and interfaces
- Configuration requirements (what values are needed, format, constraints)
- Security considerations (why certain checks exist, security implications)
- Performance trade-offs (why this approach was chosen over alternatives)
- Architectural decisions (ADRs - Architecture Decision Records)
- Domain concepts and ubiquitous language (DDD terminology)

---

## When NOT to Document

- Self-evident code (clear variable names, obvious logic)
- Standard patterns (common design patterns don't need explanation)
- What the code does (the code shows this - focus on **why**)
- Code style/formatting (linters and formatters handle this)
- Implementation details that are obvious from reading the code

---

## Documentation Formats

### Inline Comments
Use sparingly for non-obvious logic:
```typescript
// Using binary search because array is pre-sorted (O(log n) vs O(n))
const index = binarySearch(sortedArray, target);
```

### Function/Method Documentation
For public APIs only:
```typescript
/**
 * Processes payment with retry logic for transient failures.
 * @throws PaymentError if payment fails after all retries
 */
async function processPayment(amount: number): Promise<Receipt>
```

### README Files
Minimal and actionable:
- Prerequisites
- Installation steps
- Configuration (environment variables, config files)
- Running the application
- Testing

### Architecture Decision Records (ADRs)
For significant architectural choices:
- Context: What forces led to this decision?
- Decision: What was chosen?
- Consequences: What are the trade-offs?
