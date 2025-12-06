# Static Error Messages Rule

## Core Principle

**CRITICAL: Error messages MUST be static strings without dynamic values (IDs, names, etc.)**

**Dynamic values MUST go in:**

1. Exception context/properties (if the exception class supports it)
2. Log entries (always log before throwing)

**Dynamic values MUST NOT go in:**

- The error message string itself

## Why This Matters

Error tracking tools like Sentry group errors by their message strings. Dynamic error messages create the following problems:

1. **Error fragmentation** - Each unique ID creates a separate error entry
2. **Impossible to track patterns** - Can't see if "User 123 not found" and "User 456 not found" are the same issue
3. **Alert fatigue** - Each variation triggers separate alerts
4. **Resource waste** - Sentry/monitoring costs increase with unique error messages
5. **Lost context** - Can't see frequency or impact of the actual error type

## The Rule

### ❌ FORBIDDEN - Dynamic values in error messages:

```typescript
throw new Error(`User ${userId} not found`);
throw new Error(`Period ${periodId} does not exist`);
throw new ValidationError(`Report ${reportId} is invalid`);
throw new Error(`Failed to process order ${orderId}`);
```

### ✅ REQUIRED - Static messages with context in exception properties or logs:

**Option 1: Exception with context properties (preferred when exception class supports it):**

```typescript
class NotFoundError extends Error {
  constructor(
    message: string,
    public readonly context?: Record<string, unknown>,
  ) {
    super(message);
  }
}

throw new NotFoundError("User not found", { userId });
throw new ValidationError("Period does not exist", { periodId });
throw new NotFoundError("Report not found", { reportId, organizationId });
```

**Option 2: Logging context before throwing (always acceptable):**

```typescript
logger.warn("user not found", { userId });
throw new Error("User not found");

logger.warn("period not found", { periodId });
throw new ValidationError("Period does not exist");

logger.warn("report invalid", { reportId, reason });
throw new ValidationError("Report is invalid");
```

**Option 3: Both exception context AND logging (best for debugging):**

```typescript
logger.error("order processing failed", { orderId, error });
throw new OrderProcessingError("Failed to process order", {
  orderId,
  step: "payment",
});
```

### ✅ REQUIRED - Static messages with contextual logging:

```typescript
logger.warn("user not found", { userId });
throw new Error("User not found");

logger.warn("period not found", { periodId });
throw new ValidationError("Period does not exist");

logger.warn("report invalid", { reportId, reason });
throw new ValidationError("Report is invalid");

logger.error("order processing failed", { orderId, error });
throw new Error("Failed to process order");
```

## Implementation Pattern

**CHOOSE the appropriate pattern based on your exception class capabilities:**

### Pattern A: Exception with Context Properties (Preferred)

Use when your exception class supports context/metadata properties:

```typescript
// ✅ BEST - Context in exception and logs
if (!report) {
  logger.warn("report not found", { reportId: body.report_id });
  throw new NotFoundError("Report not found", { reportId: body.report_id });
}

// ✅ ACCEPTABLE - Context in exception only (if exception is captured by error tracking)
if (!report) {
  throw new NotFoundError("Report not found", { reportId: body.report_id });
}
```

### Pattern B: Logging Only

Use when your exception class doesn't support context properties:

```typescript
// ✅ CORRECT - Context in logs
if (!report) {
  logger.warn("report not found", { reportId: body.report_id });
  throw new ValidationError("Report does not exist");
}
```

### Pattern C: Never Use

```typescript
// ❌ WRONG - Dynamic value in message string
if (!report) {
  throw new ValidationError(`Report ${body.report_id} does not exist`);
}

// ❌ WRONG - Even with logging, message must still be static
if (!report) {
  logger.warn("report not found", { reportId: body.report_id });
  throw new ValidationError(`Report ${body.report_id} does not exist`);
}
```

## Benefits

### In Sentry/Error Tracking

- **Single error group** for "User not found" across all users
- **Aggregate metrics** show actual impact (1000 occurrences vs 1000 unique errors)
- **Meaningful alerts** based on error type, not individual instances
- **Trend analysis** possible when errors are properly grouped
- **Context still captured** via exception properties or breadcrumbs/tags

### For Debugging

- **Context available** in exception properties (structured data)
- **Context available** in logs with all dynamic values
- **Correlation IDs** can link log entries to errors
- **Stack traces** remain unchanged
- **Better signal-to-noise** in error monitoring dashboards
- **Queryable metadata** when using exception context properties

## Examples by Domain

### API Validation Errors

```typescript
// ❌ WRONG
throw new ValidationError(`Invalid email: ${email}`);

// ✅ CORRECT - With exception context
throw new ValidationError("Invalid email format", { email, userId });

// ✅ CORRECT - With logging
logger.warn("invalid email format", { email, userId });
throw new ValidationError("Invalid email format");
```

### Database Errors

```typescript
// ❌ WRONG
throw new Error(`Failed to insert record ${recordId} into ${tableName}`);

// ✅ CORRECT - With exception context
throw new DatabaseError("Database insert failed", {
  recordId,
  tableName,
  operation: "insert",
});

// ✅ CORRECT - With logging
logger.error("database insert failed", { recordId, tableName, error });
throw new Error("Database insert failed");
```

### External API Errors

```typescript
// ❌ WRONG
throw new Error(`GitHub API returned ${statusCode} for repo ${repoName}`);

// ✅ CORRECT - With exception context
throw new ExternalAPIError("GitHub API request failed", {
  statusCode,
  repoName,
  endpoint,
});

// ✅ CORRECT - With logging
logger.error("github api error", { statusCode, repoName, response });
throw new Error("GitHub API request failed");
```

### Resource Not Found

```typescript
// ❌ WRONG
throw new NotFoundError(`Report ${reportId} not found`);
throw new NotFoundError(`User ${userId} does not exist`);

// ✅ CORRECT - With exception context
throw new NotFoundError("Report not found", { reportId });
throw new NotFoundError("User not found", { userId });

// ✅ CORRECT - With logging
logger.warn("report not found", { reportId });
throw new NotFoundError("Report not found");

logger.warn("user not found", { userId });
throw new NotFoundError("User not found");
```

### Database Errors

```typescript
// ❌ WRONG
throw new Error(`Failed to insert record ${recordId} into ${tableName}`);

// ✅ CORRECT
logger.error("database insert failed", { recordId, tableName, error });
throw new Error("Database insert failed");
```

### External API Errors

```typescript
// ❌ WRONG
throw new Error(`GitHub API returned ${statusCode} for repo ${repoName}`);

// ✅ CORRECT
logger.error("github api error", { statusCode, repoName, response });
throw new Error("GitHub API request failed");
```

### Resource Not Found

```typescript
// ❌ WRONG
throw new NotFoundError(`Report ${reportId} not found`);
throw new NotFoundError(`User ${userId} does not exist`);

// ✅ CORRECT
logger.warn("report not found", { reportId });
throw new NotFoundError("Report not found");

logger.warn("user not found", { userId });
throw new NotFoundError("User not found");
```

## Edge Cases

### When IDs are part of the error TYPE

If the error type genuinely differs based on the ID (rare), use categorization:

```typescript
// ✅ ACCEPTABLE - Different error types
if (userId === SYSTEM_USER_ID) {
  throw new Error("Cannot delete system user");
} else {
  logger.warn("user not found", { userId });
  throw new Error("User not found");
}
```

### Configuration Errors

```typescript
// ❌ WRONG
throw new Error(`Missing required config: ${configKey}`);

// ✅ CORRECT - With exception context
throw new ConfigurationError("Missing required configuration", { configKey });

// ✅ CORRECT - With logging
logger.error("missing required configuration", { configKey });
throw new Error("Missing required configuration");
```

## Creating Context-Aware Exception Classes

If you find yourself frequently needing context, create exception classes that support it:

```typescript
// Base class for exceptions with context
export class AppError extends Error {
  constructor(
    message: string,
    public readonly context?: Record<string, unknown>,
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

// Specific error types
export class NotFoundError extends AppError {}
export class ValidationError extends AppError {}
export class ExternalAPIError extends AppError {}

// Usage
throw new NotFoundError("User not found", { userId, requestId });
throw new ValidationError("Invalid input", { field: "email", value: email });
```

This allows error tracking systems to:

1. Group by message (error type)
2. Access context via exception properties
3. Create meaningful dashboards and alerts

## Enforcement

### Code Review Checklist

- [ ] All `throw` statements use static strings for the message
- [ ] Dynamic context is either:
  - Passed as exception context/properties, OR
  - Logged before throwing
- [ ] Error messages describe the error type, not the instance
- [ ] No template literals or string concatenation in error messages

### When You See Dynamic Error Messages

1. **Check if exception class supports context** - If yes, pass context as properties
2. **Add contextual logging** before the throw (always recommended)
3. **Replace dynamic message** with static equivalent
4. **Preserve all context** in exception properties or log entry
5. **Update tests** if they assert on error messages

## Common Patterns to Fix

### Pattern 1: ID in message

```typescript
// BEFORE
throw new Error(`Record ${id} not found`);

// AFTER (with context)
throw new NotFoundError("Record not found", { id });

// AFTER (with logging)
logger.warn("record not found", { id });
throw new Error("Record not found");
```

### Pattern 2: Multiple dynamic values

```typescript
// BEFORE
throw new Error(`Failed to sync ${count} items for user ${userId}`);

// AFTER (with context)
throw new SyncError("Sync failed", { count, userId });

// AFTER (with logging)
logger.error("sync failed", { count, userId });
throw new Error("Sync failed");
```

### Pattern 3: Status codes

```typescript
// BEFORE
throw new Error(`API returned status ${status}`);

// AFTER (with context)
throw new ExternalAPIError("API request failed", { status, url, response });

// AFTER (with logging)
logger.error("api request failed", { status, url, response });
throw new Error("API request failed");
```

### Pattern 2: Multiple dynamic values

```typescript
// BEFORE
throw new Error(`Failed to sync ${count} items for user ${userId}`);

// AFTER
logger.error("sync failed", { count, userId });
throw new Error("Sync failed");
```

### Pattern 3: Status codes

```typescript
// BEFORE
throw new Error(`API returned status ${status}`);

// AFTER
logger.error("api request failed", { status, url, response });
throw new Error("API request failed");
```

## Remember

**Three places for dynamic context (in order of preference):**

1. **Exception context properties** - Structured, queryable, captured by error tracking
2. **Log entries** - Always valuable for debugging, provides timeline context
3. **Both** - Recommended for critical errors

**NEVER in:**

- Error message strings

**The error message is for error grouping and alerting.**
**The exception context and log entries are for debugging and analysis.**

Separate these concerns for better observability and maintainability.
