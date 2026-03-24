# Item Watermark

The client sends the last-known `system_from` for a specific resource in the request. If the server's current `system_from` matches, nothing has changed — the server returns HTTP 304 with no body. This maps directly to standard HTTP conditional request semantics.

## Concept

In a temporal table, every update creates a new row with a new `system_from`. The `system_from` of the current row (where `system_to = FAR_FUTURE`) uniquely identifies the current version. This makes it a natural ETag.

```
Client                              Server
  │                                   │
  │  GET /api/blueprints/bp-1         │
  │──────────────────────────────────►│
  │                                   │  system_from = "2024-06-15T14:30:00Z"
  │  200 OK                           │
  │  ETag: "2024-06-15T14:30:00Z"     │
  │  { ...blueprint data... }         │
  │◄──────────────────────────────────│
  │                                   │
  │  GET /api/blueprints/bp-1         │
  │  If-None-Match: "2024-06-15..."   │
  │──────────────────────────────────►│
  │                                   │  system_from still = "2024-06-15..."
  │  304 Not Modified                 │
  │◄──────────────────────────────────│
  │                                   │
  │  GET /api/blueprints/bp-1         │
  │  If-None-Match: "2024-06-15..."   │
  │──────────────────────────────────►│
  │                                   │  system_from now = "2024-06-20..."
  │  200 OK                           │
  │  ETag: "2024-06-20T09:00:00Z"     │
  │  { ...updated data... }           │
  │◄──────────────────────────────────│
```

## Server Side

### SQL: Check if item has changed

```sql
SELECT * FROM blueprints
WHERE id = @blueprint_id
  AND system_to = '9999-12-31 23:59:59';
```

Compare the result's `system_from` against the client's `If-None-Match` value. If they match, return 304.

### Optimized query: avoid fetching data when unchanged

```sql
SELECT system_from FROM blueprints
WHERE id = @blueprint_id
  AND system_to = '9999-12-31 23:59:59';
```

First fetch only `system_from`. If it matches the ETag, return 304 without reading the full row. Only fetch the full record if it doesn't match.

### HTTP handler

```typescript
app.get("/api/blueprints/:id", async (req, res) => {
  const current = await db.query.blueprints.findFirst({
    where: and(
      eq(blueprints.id, req.params.id),
      eq(blueprints.systemTo, "9999-12-31 23:59:59"),
    ),
  });

  if (!current) {
    return res.status(404).end();
  }

  const etag = `"${current.systemFrom}"`;

  if (req.headers["if-none-match"] === etag) {
    return res.status(304).end();
  }

  res.set("ETag", etag);
  res.json(current);
});
```

### Middleware approach

Extract the ETag logic into reusable middleware for any temporal endpoint:

```typescript
function temporalETag(getSystemFrom: (body: unknown) => string) {
  return (req: Request, res: Response, next: NextFunction) => {
    const originalJson = res.json.bind(res);
    res.json = (body: unknown) => {
      const systemFrom = getSystemFrom(body);
      const etag = `"${systemFrom}"`;
      res.set("ETag", etag);

      if (req.headers["if-none-match"] === etag) {
        return res.status(304).end();
      }

      return originalJson(body);
    };
    next();
  };
}

// Usage
app.get(
  "/api/blueprints/:id",
  temporalETag((body) => body.systemFrom),
  blueprintHandler,
);
```

## Client Side

### Storing the ETag

Most HTTP clients handle ETags automatically when backed by a cache. For manual control:

```typescript
const etagCache = new Map<string, string>();

async function fetchBlueprint(id: string): Promise<Blueprint | null> {
  const headers: Record<string, string> = {};
  const cachedEtag = etagCache.get(id);

  if (cachedEtag) {
    headers["If-None-Match"] = cachedEtag;
  }

  const response = await fetch(`/api/blueprints/${id}`, { headers });

  if (response.status === 304) {
    // Data unchanged — use cached version
    return getCachedBlueprint(id);
  }

  const etag = response.headers.get("ETag");
  if (etag) {
    etagCache.set(id, etag);
  }

  const blueprint = await response.json();
  setCachedBlueprint(id, blueprint);
  return blueprint;
}
```

### With React Query

React Query doesn't natively support 304 responses, but you can integrate ETags in the query function:

```typescript
const { data } = useQuery({
  queryKey: ["blueprint", blueprintId],
  queryFn: () => fetchBlueprint(blueprintId), // uses ETag logic above
  staleTime: 5 * 60 * 1000,
});
```

The `staleTime` controls how often React Query re-invokes the query function. When it does, the ETag ensures no data is transferred if nothing changed.

## HTTP Semantics

### ETag vs Last-Modified

Both work for temporal caching. ETags are more precise and flexible:

| Header          | Value                           | Conditional header  | Best for                                        |
| --------------- | ------------------------------- | ------------------- | ----------------------------------------------- |
| `ETag`          | `"2024-06-15T14:30:00Z"`        | `If-None-Match`     | Exact version matching                          |
| `Last-Modified` | `Sat, 15 Jun 2024 14:30:00 GMT` | `If-Modified-Since` | Calendar-time granularity (1-second resolution) |

**Recommendation: Use ETags with `system_from` as the value.** ETags support arbitrary precision (sub-second timestamps, version numbers) and are compared for exact equality, which maps cleanly to temporal versioning.

### Strong vs weak ETags

- **Strong ETag** (`"2024-06-15T14:30:00Z"`): The response body is byte-for-byte identical. Use when `system_from` uniquely determines the response content.
- **Weak ETag** (`W/"2024-06-15T14:30:00Z"`): The response is semantically equivalent but may differ in formatting. Use when the same data might be serialized differently (e.g., field ordering in JSON).

For temporal tables, strong ETags are usually appropriate — the same `system_from` means the same data.

### Deleted items

If a client sends an `If-None-Match` for an item that has been phased out (deleted), the server won't find a current row. Return 404, not 304:

```typescript
if (!current) {
  return res.status(404).end(); // was deleted
}
```

The client should handle 404 by clearing its cache for that item.

## Combining with Other Patterns

The item watermark is often used alongside the [global watermark](./global-watermark.md):

1. **Global watermark** detects that _something_ changed in the collection
2. Client refetches the list/feed
3. User clicks into a detail view
4. **Item watermark** avoids re-downloading the full item if it hasn't changed since the client last viewed it

This layered approach minimizes data transfer at both the collection and individual resource level.
