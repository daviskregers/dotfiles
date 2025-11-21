# Security Issues

**Priority: #4 - Always critical**

## Vulnerabilities
- **Injection attacks**: SQL injection, command injection, XSS, SSRF, LDAP injection, etc.
- **Unsafe practices**: Eval, unsafe deserialization, insecure randomness
- **Exposure risks**: Secrets in code, PII logging, sensitive data in URLs, verbose error messages exposing internals
- **Authentication/authorization flaws**: Missing checks, privilege escalation, broken access control
- **Insecure dependencies**: Outdated libraries with known vulnerabilities (check CVE databases)
- **Cryptographic weaknesses**: Weak algorithms (MD5, SHA1 for passwords), hardcoded keys, improper key storage
- **Path traversal**: File access vulnerabilities allowing directory traversal
- **OWASP Top 10**: Be aware of current top security risks

---

## Input Validation & Trust Boundaries

### Trust Boundary Concept
**Trust boundary = your validation layer.** Before validation = untrusted, after validation = trusted.

### Untrusted Input (MUST Validate)
Always validate and sanitize:
- **User input**: Form fields, query parameters, request bodies, headers, cookies
- **File uploads**: Type validation, size limits, content scanning
- **External API responses**: Third-party service data
- **Environment variables**: From config files or external sources
- **URL parameters**: Route params, query strings
- **Webhooks**: External service callbacks

**Validation requirements:**
- Schema validation (e.g., Zod, Joi) for structure
- Type checking and coercion
- Range/length validation
- Format validation (email, URL, etc.)
- Sanitization for output context (HTML escaping, SQL parameterization)

### Trusted Input (Already Validated)
Can trust after validation:
- **Your own database**: If data was validated before storing
- **Internal service responses**: Your own microservices (already validated at their boundaries)
- **Hardcoded constants**: In source code
- **Validated data**: After passing through validation layer

**Warning:** Don't trust your database blindly if:
- Data was imported from external sources without validation
- Legacy data exists from before validation was added
- Multiple systems write to same database

### Examples

```typescript
// ❌ Bad - using user input without validation
app.get('/user/:id', async (req, res) => {
  const userId = req.params.id;  // Untrusted!
  const user = await db.query(`SELECT * FROM users WHERE id = ${userId}`);  // SQL injection!
});

// ✅ Good - validate at boundary
const UserIdSchema = z.string().uuid();

app.get('/user/:id', async (req, res) => {
  const userId = UserIdSchema.parse(req.params.id);  // Validated!
  const user = await db.query('SELECT * FROM users WHERE id = ?', [userId]);  // Safe
});

// ✅ Good - trusted after validation
function processValidatedUser(user: ValidatedUser) {
  // 'user' is trusted here - already validated at the boundary
  return user.name.toUpperCase();
}
```

---

## Data Loss Prevention

### Destructive Operations
- **Require confirmation**: For irreversible actions (delete, truncate, drop)
- **Soft deletes**: Mark as deleted instead of hard delete where appropriate
- **Audit trail**: Log who deleted what and when
- **Rate limiting**: Prevent accidental bulk deletes

### Database Migrations
- **Always include `down()` migration**: Ability to rollback changes
- **Test rollback**: Verify `down()` actually works before deploying
- **Data backup strategy**: Before dropping columns/tables
  - Export data to backup table
  - Document recovery procedure
  - Set retention policy
- **Additive changes first**: Add new column, migrate data, then drop old column (not atomic drop)

### Transaction Handling
- **Rollback on error**: Use transactions for multi-step operations
- **Timeout configuration**: Prevent long-running transactions locking resources
- **Idempotency**: Operations should be safely retryable

**Example:**
```typescript
// ✅ Good - transactional with rollback
await db.transaction(async (trx) => {
  await trx.insert(orders).values(newOrder);
  await trx.update(inventory).set({ quantity: decremented });
  await trx.insert(notifications).values(notification);
  // All-or-nothing: if any fails, all rollback
});
```

---

## Security by Default Principles
- **Validate at system boundaries**: User input, external APIs, uploaded files
- **Trust internal code and framework guarantees**: Don't over-validate trusted internal calls
- **Never commit secrets or credentials**: Use environment variables, secret management services
- **Use environment variables for sensitive config**: API keys, database passwords, tokens
- **Principle of least privilege**: Grant minimum necessary permissions
- **Defense in depth**: Multiple layers of security controls
- **Fail securely**: Errors should not expose sensitive information
