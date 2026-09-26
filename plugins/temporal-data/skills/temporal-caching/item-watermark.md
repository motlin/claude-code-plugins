# Item Watermark

The `system_from` of the current row (`system_to = FAR_FUTURE`) uniquely identifies the current version, so it works as an ETag. The client sends it in `If-None-Match`; the server returns 304 when it still matches.

## Server

Fetch only `system_from` first, and read the full row only when it differs from the ETag:

```sql
SELECT system_from FROM blueprints
WHERE id = @blueprint_id
  AND system_to = '9999-12-31 23:59:59';
```

```typescript
app.get('/api/blueprints/:id', async (req, res) => {
	const current = await db.query.blueprints.findFirst({
		where: and(eq(blueprints.id, req.params.id), eq(blueprints.systemTo, '9999-12-31 23:59:59')),
	});

	if (!current) {
		return res.status(404).end();
	}

	const etag = `"${current.systemFrom}"`;

	if (req.headers['if-none-match'] === etag) {
		return res.status(304).end();
	}

	res.set('ETag', etag);
	res.json(current);
});
```

The same check can be factored into middleware for any temporal endpoint.

- Use `ETag`, not `Last-Modified`: ETags compare exactly and support sub-second precision, while `Last-Modified` has 1-second resolution.
- A strong ETag is usually right, since the same `system_from` means the same data. Use a weak ETag (`W/"..."`) only if the same data may serialize differently.
- A phased-out (deleted) item has no current row. Return 404, not 304, and have the client clear its cache for that item.

## Client

Keep a map of id to ETag. Send `If-None-Match` when one is cached; on 304, return the cached value; otherwise store the new ETag and body. React Query has no built-in 304 support, so put this logic in the `queryFn`; `staleTime` then controls how often the conditional request runs.

## With the global watermark

Use the [global watermark](./global-watermark.md) to detect that something in the collection changed and refetch the list, and the item watermark to avoid re-downloading an unchanged item when the user opens its detail view.
