# Predicate Watermark

In a one-to-many relationship, the parent stores the maximum `system_from` of its children in a denormalized column. The client checks that one value before deciding whether to fetch the whole child collection.

Example: fetching all of a user's blueprints is expensive, but fetching the user is cheap. If the user carries `last_blueprint_updated`, the client skips the collection fetch when it matches the cached value.

## Schema

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

`last_blueprint_updated` is not a temporal column. It is a denormalized aggregate updated through the parent's normal phase-out / phase-in lifecycle.

## Writes

Every child create, update, or delete also writes a new parent version in the same transaction:

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

The parent watermark and child data must change atomically; if they drift, the client may skip a needed fetch.

## Reads

The client fetches the parent (itself cacheable with the [item watermark](./item-watermark.md)), compares `lastBlueprintUpdated` with its cached watermark for that parent, and returns cached children on a match. Otherwise it fetches the collection and stores both the children and the new watermark.

The collection endpoint can also be conditional: for `GET /api/users/user-1/blueprints` with `If-None-Match`, compare against the user's `last_blueprint_updated` and return 304 without querying the child table.

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

## Trade-offs

- **Write amplification**: every child write creates a parent version. Not worth it when children change often and the parent is rarely read.
- **Granularity**: one changed child refetches the whole collection. Add a [global watermark](./global-watermark.md) on the child collection for finer detection.

Use it when the child collection is expensive to fetch, the parent is cheap or already fetched, and children change infrequently relative to reads.
