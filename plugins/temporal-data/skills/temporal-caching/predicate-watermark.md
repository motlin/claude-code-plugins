# Predicate Watermark

In a one-to-many relationship, the parent entity stores the maximum `system_from` of its children as a denormalized column. The client can check this single value to decide whether fetching the full child collection is necessary.

## Concept

Consider a user who owns many blueprints. Fetching all of a user's blueprints is expensive. But fetching the user record is cheap. If the user record carries a `last_blueprint_updated` timestamp, the client can compare it against its cached value and skip the collection fetch entirely when nothing changed.

```
User (parent)                    Blueprints (children)
┌──────────────────────────┐     ┌─────────────────────────┐
│ id: "user-1"             │     │ id: "bp-1"              │
│ display_name: "Alice"    │     │ user_id: "user-1"       │
│ last_blueprint_updated:  │◄────│ system_from: 2024-06-15 │
│   2024-06-15 14:30:00    │     │ system_to: 9999-12-31   │
│ system_from: ...         │     ├─────────────────────────┤
│ system_to: 9999-12-31    │     │ id: "bp-2"              │
└──────────────────────────┘     │ user_id: "user-1"       │
                                 │ system_from: 2024-06-10 │
                                 │ system_to: 9999-12-31   │
                                 └─────────────────────────┘
```

## Schema

Add a denormalized watermark column to the parent table:

```sql
CREATE TABLE users (
  id TEXT NOT NULL,
  display_name TEXT,
  last_blueprint_updated TEXT NOT NULL DEFAULT '1970-01-01 00:00:00',
  system_from TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
  system_to TEXT NOT NULL DEFAULT '9999-12-31 23:59:59',
  PRIMARY KEY (id, system_to)
);
```

The `last_blueprint_updated` column is not itself a temporal column — it's a denormalized aggregate that gets updated as part of the parent's normal temporal lifecycle (phase out old version, insert new version with updated value).

## Write Side

When a child is created, updated, or deleted, update the parent's watermark in the same transaction:

```sql
BEGIN TRANSACTION;

-- Phase out old parent version
UPDATE users
SET system_to = @now
WHERE id = @user_id AND system_to = '9999-12-31 23:59:59';

-- Insert new parent version with advanced watermark
INSERT INTO users (id, display_name, last_blueprint_updated, system_from, system_to)
SELECT id, display_name, @now, @now, '9999-12-31 23:59:59'
FROM users
WHERE id = @user_id AND system_to = @now;

-- Now perform the child operation (insert/update/delete)
-- ...

COMMIT;
```

This means every child write also writes a new version of the parent. The parent's `last_blueprint_updated` always equals the `system_from` of the most recent child operation.

## Read Side

### Server endpoint

```
GET /api/users/user-1
```

Response includes `last_blueprint_updated`:

```json
{
	"id": "user-1",
	"displayName": "Alice",
	"lastBlueprintUpdated": "2024-06-15T14:30:00Z"
}
```

### Client-side skip logic

```typescript
async function fetchUserBlueprints(userId: string): Promise<Blueprint[]> {
	// Step 1: Fetch (or use cached) parent record
	const user = await fetchUser(userId);

	// Step 2: Compare against stored watermark
	const cachedWatermark = getCachedWatermark(`user-blueprints-${userId}`);

	if (cachedWatermark === user.lastBlueprintUpdated) {
		// Nothing changed — use cached blueprints
		return getCachedBlueprints(userId);
	}

	// Step 3: Fetch full collection
	const blueprints = await fetch(`/api/users/${userId}/blueprints`);

	// Step 4: Update watermark
	setCachedWatermark(`user-blueprints-${userId}`, user.lastBlueprintUpdated);
	setCachedBlueprints(userId, blueprints);

	return blueprints;
}
```

### Combining with item watermark

The parent fetch in step 1 can itself use the [item watermark](./item-watermark.md) pattern — send the parent's `system_from` as an ETag, get a 304 if it hasn't changed. This means both the parent check and the child collection fetch can be skipped when nothing changed.

## REST Endpoint Design

The predicate watermark can also be exposed as a conditional collection endpoint:

```
GET /api/users/user-1/blueprints
If-None-Match: "2024-06-15T14:30:00Z"
```

The server checks the user's `last_blueprint_updated` against the `If-None-Match` value. If they match, return 304 without querying the child table at all.

```typescript
app.get('/api/users/:userId/blueprints', async (req, res) => {
	const user = await getCurrentUser(req.params.userId);
	const etag = `"${user.lastBlueprintUpdated}"`;

	if (req.headers['if-none-match'] === etag) {
		return res.status(304).end();
	}

	const blueprints = await fetchBlueprints(req.params.userId);
	res.set('ETag', etag);
	res.json(blueprints);
});
```

## Trade-Offs

**Write amplification**: Every child write also creates a new parent version. For systems where children change frequently and the parent is rarely read, this overhead may not be worthwhile.

**Consistency**: The parent watermark and child data must be updated atomically. If they get out of sync (e.g., parent updated but child write fails), the client may skip a necessary fetch. Always wrap both in the same transaction.

**Granularity**: One watermark per predicate (e.g., per user). If a user has thousands of blueprints and only one changed, the client still refetches the entire collection. Combine with the [global watermark](./global-watermark.md) pattern on the child collection for finer-grained detection.

## When to Use

- The child collection is expensive to fetch (many records, complex joins)
- The parent is cheap to fetch or is already being fetched for other reasons
- The child collection changes infrequently relative to how often it's read
- You can tolerate the write amplification on the parent
