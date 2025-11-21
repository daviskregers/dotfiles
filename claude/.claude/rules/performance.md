# Performance Issues

**Priority: #2 - Focus on substantive engineering issues**

## Algorithmic Efficiency

### Common Issues
- **Bottlenecks**: Identify hot paths and expensive operations
- **Inefficient algorithms**: O(n²) where O(n) or O(log n) is possible
- **Unnecessary computations**: Redundant calculations, repeated work
- **Data structure choices**: Wrong structure for the access pattern

### Algorithm & Data Structure Improvements

#### Linear Search → Hash-Based Lookup
```typescript
// ❌ O(n) - linear search in array
const userIds = [1, 2, 3, 4, 5];
if (userIds.includes(targetId)) { /* ... */ }

// ✅ O(1) - Set lookup
const userIds = new Set([1, 2, 3, 4, 5]);
if (userIds.has(targetId)) { /* ... */ }
```

#### Nested Loops → HashMap
```typescript
// ❌ O(n²) - nested loops
const matches = [];
for (const user of users) {
  for (const order of orders) {
    if (user.id === order.userId) matches.push({ user, order });
  }
}

// ✅ O(n) - hashmap
const ordersByUserId = new Map();
for (const order of orders) {
  ordersByUserId.set(order.userId, order);
}
const matches = users.map(user => ({
  user,
  order: ordersByUserId.get(user.id)
}));
```

#### Array for Existence Check → Set
```typescript
// ❌ O(n) - using .find() for existence
const hasAccess = permissions.find(p => p.userId === userId);

// ✅ O(1) - Set for existence checks
const permissionSet = new Set(permissions.map(p => p.userId));
const hasAccess = permissionSet.has(userId);
```

#### Frequent Insertions/Deletions
```typescript
// ❌ Array splice is O(n)
array.splice(index, 1);  // Shifts all elements after index

// ✅ Use Set/Map for O(1) add/remove if order doesn't matter
const items = new Set();
items.delete(item);  // O(1)

// ✅ Use linked list if order matters and frequent insertions
```

#### Missing Early Termination
```typescript
// ❌ Processes all items even after finding result
let found = false;
for (const item of items) {
  if (item.id === targetId) found = true;
  // Continues processing...
}

// ✅ Early termination
for (const item of items) {
  if (item.id === targetId) return item;
}
```

---

## Memory Management
- **Memory leaks**: Unreleased resources, circular references, event listeners not cleaned up
- **Garbage collection pressure**: Excessive allocations in hot paths
- **Memory bloat**: Holding references longer than necessary
- **Large object retention**: Keeping entire objects when only small parts are needed
- **Memory fragmentation**: Allocation patterns that cause fragmentation

---

## Resource Management
- **Resource leaks**: File handles, database connections, network sockets, timers not properly closed
- **Connection pooling**: Missing or misconfigured pools
- **Unbounded growth**: Caches, queues, or collections without limits
- **Zombie resources**: Resources that should be cleaned up but aren't (subscriptions, intervals)

---

## Concurrency & Blocking

### Blocking Issues
- **Blocking operations on main/UI threads**: Synchronous I/O, heavy computation
- **Thread pool starvation**: Too much blocking work on limited thread pools
- **Deadlocks**: Circular lock dependencies
- **Lock contention**: Hot locks causing serialization

### Race Conditions
Watch for concurrent operations modifying shared state:

```typescript
// ❌ Race condition - read-modify-write without locking
const balance = await getBalance(accountId);
if (balance >= amount) {
  // Another request could modify balance here!
  await updateBalance(accountId, balance - amount);
}

// ✅ Atomic operation with database lock
await db.transaction(async (trx) => {
  const account = await trx
    .select()
    .from(accounts)
    .where(eq(accounts.id, accountId))
    .forUpdate();  // Lock row for this transaction

  if (account.balance >= amount) {
    await trx.update(accounts)
      .set({ balance: account.balance - amount })
      .where(eq(accounts.id, accountId));
  }
});
```

**Common race condition patterns:**
- **Check-then-act**: Check condition, then act on it (state may change between check and act)
- **Read-modify-write**: Read value, compute new value, write back (another process may modify between read and write)
- **Concurrent updates**: Multiple requests updating same record simultaneously
- **Missing transaction isolation**: Operations that should be atomic aren't in a transaction

**When to worry about race conditions:**
- Financial operations (payments, transfers, credits)
- Inventory management (stock levels, reservations)
- User account operations (concurrent profile updates)
- Rate limiting (increment counters)
- Resource allocation (assigning limited resources)

### Parallelization Opportunities

#### Sequential Independent Operations → Parallel
```typescript
// ❌ Sequential - takes 3 seconds if each takes 1 second
const user = await fetchUser(userId);
const orders = await fetchOrders(userId);
const preferences = await fetchPreferences(userId);

// ✅ Parallel - takes 1 second (longest operation)
const [user, orders, preferences] = await Promise.all([
  fetchUser(userId),
  fetchOrders(userId),
  fetchPreferences(userId)
]);
```

#### Independent API Calls
```typescript
// ❌ Sequential API calls
const weatherData = await fetch('/api/weather');
const newsData = await fetch('/api/news');
const stockData = await fetch('/api/stocks');

// ✅ Parallel API calls
const [weatherData, newsData, stockData] = await Promise.all([
  fetch('/api/weather'),
  fetch('/api/news'),
  fetch('/api/stocks')
]);
```

#### Independent Database Queries
```typescript
// ❌ Sequential queries
const users = await db.select().from(usersTable);
const products = await db.select().from(productsTable);
const categories = await db.select().from(categoriesTable);

// ✅ Parallel queries (if on separate connections/transactions)
const [users, products, categories] = await Promise.all([
  db.select().from(usersTable),
  db.select().from(productsTable),
  db.select().from(categoriesTable)
]);
```

**Watch for race conditions when parallelizing:**
- Don't parallelize if operations share state (use locks/transactions)
- Ensure transaction isolation for database operations
- Consider ordering dependencies (operation B depends on operation A's result)

---

## Data Access Patterns
- **N+1 queries**: Loading related data in loops instead of batch/eager loading
- **Missing indexes**: Queries scanning full tables
- **Over-fetching**: Loading more data than needed (select * when only need few columns)
- **Under-fetching**: Multiple round trips when one would suffice
- **Cache misses**: Missing caching opportunities for expensive operations

---

## Network & I/O
- **Chatty APIs**: Too many small requests instead of batch operations
- **Missing compression**: Large payloads without compression
- **Synchronous chains**: Sequential operations that could be parallel
- **Timeout configurations**: Missing or inappropriate timeouts
- **Retry storms**: Aggressive retries without backoff
