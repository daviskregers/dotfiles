# Operational Standards

## Observability for Long-Running Operations

For builds, deployments, tests, migrations, or any operation >5 seconds:

- **Use verbose flags**: `-v`, `--verbose`, `--progress`, `--print-build-logs`
- **Echo operations before running**: "Deploying to production..."
- **Show progress**: "Check 1/12...", "Processing file 3 of 50..."
- **Confirm success explicitly**: "✓ Deployment complete", "✓ All tests passed"
- **Never use silent operations** that leave users wondering if it's stuck

---

## Health Checks

- Echo what test is being performed before running it
- Show retry counters for operations with retries
- Display intermediate results to show progress
- Confirm explicitly when checks pass

### Example
```bash
echo "Testing database connectivity..."
echo "Attempt 1/10..."
# run test
echo "✓ Database connection successful"

echo "Testing API endpoint health..."
echo "Attempt 1/10..."
# run test
echo "✓ API responding correctly"
```

---

## Deployment Visibility

Always provide verbose output during deployments:

- Add `echo` statements to mark deployment phases
- Use verbose flags for tools (`-v`, `--verbose`, `--progress`, `--print-build-logs`)
- Show what's being copied, built, or activated
- Long-running operations must display real-time progress
- Users should never wonder if a deployment is stuck or progressing

---

## Principle

**Users should never wonder if an operation is stuck or progressing.**

Silent operations cause anxiety and uncertainty. Verbose output builds confidence that the system is working correctly.
