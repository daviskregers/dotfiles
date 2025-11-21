# TypeScript/JavaScript Standards

## Configuration Values - Fail Fast

- **Never use hardcoded fallbacks** with `||` operator for configuration values (IPs, ports, hostnames, API keys)
- Use non-null assertions or explicit checks to ensure configuration is properly set
- Let the code fail at build/runtime if required configuration is missing

### Bad Examples
```typescript
const host = config.network.public?.ip || '192.168.89.250';
const apiKey = process.env.API_KEY || 'default-key';
const port = config.server?.port || 3000;
```

### Good Examples
```typescript
// Non-null assertion - fails if not configured
const host = config.network.public!.ip;

// Explicit check with clear error
const apiKey = process.env.API_KEY;
if (!apiKey) throw new Error('API_KEY environment variable required');

// For optional values with legitimate defaults, be explicit
const port = config.server?.port ?? 3000;  // Use ?? for intentional defaults
```

### Principle
**Silent fallbacks hide configuration errors.** Fail fast and explicitly. Build-time failures are better than runtime surprises in production.

### When Defaults Are Acceptable
Use `??` (nullish coalescing) for values that legitimately have sensible defaults:
- UI preferences (theme, language)
- Performance tuning (cache size, timeout values with reasonable defaults)
- Feature flags that default to off

But **never** for:
- Connection strings
- API keys/secrets
- Service endpoints
- Critical business configuration
