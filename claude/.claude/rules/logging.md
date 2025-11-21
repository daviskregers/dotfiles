# Logging Standards

## Logging Levels - When to Use Each

### ERROR - Operation Failed, Cannot Continue
Use `error` when:
- Operation failed and cannot continue (thrown exception, unhandled failure)
- External service unreachable (database down, API timeout)
- Data corruption or integrity violation
- Security breach attempt
- Unrecoverable errors that require immediate attention

**Examples:**
```typescript
logger.error('Database connection failed', { error, connectionString: sanitized });
logger.error('Payment processing failed', { orderId, error });
logger.error('Authentication bypass attempt detected', { userId, ip });
```

**NOT for:**
- Expected validation failures (use `warn` or `info`)
- Handled exceptions that have fallbacks (use `warn`)
- Debugging information (use `debug`)

---

### WARN - Unexpected But Handled
Use `warn` when:
- Deprecated API usage
- Degraded functionality (fallback used, retry succeeded)
- Unexpected but handled condition (invalid cache, missing optional config)
- Resource threshold approaching (disk 80% full)
- Operations that succeeded on retry after initial failure

**Examples:**
```typescript
logger.warn('Using deprecated API endpoint', { endpoint, deprecationDate });
logger.warn('Cache miss, falling back to database', { key });
logger.warn('Disk space approaching threshold', { usage: '85%' });
logger.warn('API call failed, retry succeeded', { attempt: 2, endpoint });
```

**NOT for:**
- Critical failures (use `error`)
- Normal business operations (use `info`)
- Detailed diagnostics (use `debug`)

---

### INFO - Expected Business Events
Use `info` when:
- Expected business events (user login, order placed, payment completed)
- System lifecycle events (service started, scheduled job completed)
- Important state changes (feature flag toggled, configuration updated)
- Successful completion of significant operations

**Examples:**
```typescript
logger.info('User logged in', { userId, ip });
logger.info('Order placed', { orderId, userId, total });
logger.info('Service started', { version, environment });
logger.info('Scheduled job completed', { jobName, duration });
```

**NOT for:**
- Error conditions (use `error`)
- Diagnostic details (use `debug`)
- Every function call (too noisy)

---

### DEBUG - Diagnostic Details for Troubleshooting
Use `debug` when:
- Request/response details for troubleshooting
- Function entry/exit with parameters
- Intermediate calculation values
- External API call details (request/response payloads)
- Complex conditional logic decisions
- Data transformation input/output

**Examples:**
```typescript
logger.debug('API request', { method, url, headers, body });
logger.debug('Function entered', { functionName, params });
logger.debug('Calculation result', { input, output, formula });
logger.debug('Conditional branch taken', { condition, value });
```

**NOT for:**
- Production logs (disable or filter in production)
- Business events (use `info`)
- Performance-critical paths (overhead adds up)

---

## What NOT to Log (Security & Privacy)

**Never log:**
- Passwords (plaintext or hashed)
- API keys, tokens, secrets
- Credit card numbers, CVV codes
- Social security numbers
- Personal health information (PHI)
- Personally identifiable information (PII) without anonymization
- Session tokens
- Private encryption keys

**Sanitize before logging:**
- Email addresses (mask: `u***@example.com`)
- IP addresses (consider privacy regulations)
- User IDs in public logs
- Request/response bodies containing sensitive data

---

## Diagnostic Logging Requirements

### Error Catch Blocks - Always Log Context
```typescript
// ❌ Bad - no context
try {
  await processPayment(order);
} catch (error) {
  throw error;  // Lost context!
}

// ✅ Good - log with context
try {
  await processPayment(order);
} catch (error) {
  logger.error('Payment processing failed', {
    orderId: order.id,
    amount: order.total,
    error: error.message,
    stack: error.stack
  });
  throw error;
}
```

### External API Calls - Log Request/Response
```typescript
// ✅ Log external calls for debugging
logger.debug('Calling external API', { url, method, headers: sanitizedHeaders });
const response = await fetch(url, options);
logger.debug('External API response', { status: response.status, body: await response.json() });
```

### Complex Logic - Log Decisions
```typescript
// ✅ Log conditional logic decisions
if (userAge >= votingAge && hasValidId) {
  logger.debug('User eligible to vote', { userId, userAge, votingAge });
  allowVoting();
} else {
  logger.debug('User not eligible to vote', { userId, userAge, hasValidId });
  denyVoting();
}
```

### Data Transformations - Log Input/Output
```typescript
// ✅ Log transformation details for debugging
logger.debug('Transforming user data', { input: rawData });
const transformed = transformUserData(rawData);
logger.debug('Transformation complete', { output: transformed });
```

---

## Structured Logging

Use structured logging with context objects, not string concatenation:

```typescript
// ❌ Bad - string concatenation, hard to parse
logger.info(`User ${userId} placed order ${orderId} for $${total}`);

// ✅ Good - structured with context
logger.info('Order placed', {
  userId,
  orderId,
  total,
  currency: 'USD',
  timestamp: new Date().toISOString()
});
```

**Benefits:**
- Machine-parseable
- Searchable by specific fields
- Better for log aggregation tools
- Consistent format across services

---

## Performance Considerations

- **Avoid logging in hot loops** - significant overhead
- **Use appropriate log levels** - disable `debug` in production
- **Lazy evaluation** - don't compute expensive values unless logging is enabled
- **Async logging** - don't block on log writes in critical paths

```typescript
// ❌ Bad - computes even if debug disabled
logger.debug(`Complex calculation: ${expensiveComputation()}`);

// ✅ Good - only computes if debug enabled
if (logger.isDebugEnabled()) {
  logger.debug('Complex calculation', { result: expensiveComputation() });
}
```

---

## Summary

**Quick Reference:**
- `error`: Cannot continue, needs immediate attention
- `warn`: Unexpected but handled, degraded functionality
- `info`: Expected business events, important state changes
- `debug`: Diagnostic details for troubleshooting

**Golden Rules:**
1. Log context, not just messages
2. Never log secrets or PII
3. Use structured logging
4. Match log level to severity
5. Don't log in hot paths
