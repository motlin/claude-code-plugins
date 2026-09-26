# Global Watermark

The client stores one timestamp, the maximum `system_from` seen across a collection, and polls for records newer than it. An empty result means nothing changed.

## Server

```sql
SELECT * FROM blueprints
WHERE system_from > @high_watermark
  AND system_to = '9999-12-31 23:59:59'
ORDER BY system_from DESC
LIMIT @page_size;
```

Use strict `>` so the record that set the watermark is not re-fetched.

### Deletions

A phase-out changes `system_to`, not `system_from`, so a query on `system_from` alone misses deletions. Either query both:

```sql
-- New or updated records
SELECT id, 'upsert' AS change_type, * FROM blueprints
WHERE system_from > @high_watermark AND system_to = '9999-12-31 23:59:59';

-- Phased-out (deleted) records
SELECT id, 'delete' AS change_type FROM blueprints
WHERE system_to > @high_watermark AND system_to != '9999-12-31 23:59:59';
```

Or keep a dedicated change log:

```sql
CREATE TABLE change_log (
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  change_type TEXT NOT NULL,  -- 'upsert' or 'delete'
  changed_at TEXT NOT NULL,
  PRIMARY KEY (entity_type, entity_id, changed_at)
);
```

### Endpoint

`GET /api/blueprints?since=2024-06-15T14:30:00Z&limit=100` returns the changed records plus metadata. `highWatermark` is the max `system_from` in the result set.

```json
{
  "data": [...],
  "_metadata": {
    "highWatermark": "2024-06-15T15:00:00Z",
    "hasMore": false
  }
}
```

## Client

Store the watermark durably (localStorage in browsers, a database row in backend services). On each poll, if data comes back, save `_metadata.highWatermark` and invalidate the relevant caches (e.g. `queryClient.invalidateQueries({queryKey: ['blueprints']})`). If nothing comes back, do nothing.

With no watermark yet, fetch the first page normally and seed the watermark from the max `systemFrom` in it. Only ever advance the watermark, never move it backward.

## Example: Factorio Prints

[Factorio Prints](https://www.factorio.school) keeps its blueprint feed current this way.

- `fetchSummariesNewerThan` in `src/api/firebase.ts` queries `/blueprintSummaries/` with `orderByChild('lastUpdatedDate')`, `startAt(highWatermark + 1)`, `limitToLast(100)`.
- `useHighWatermarkSync` in `src/hooks/useHighWatermarkSync.ts` polls every 5 minutes via React Query's `refetchInterval`, reads the watermark from localStorage, and on new summaries advances it and invalidates the paginated query cache. No new summaries returns `[]` with no UI update.
- `useRawPaginatedBlueprintSummaries` seeds the watermark on each page load with `Math.max(...lastUpdatedDate)` via `updateHighWatermark()`, which only advances.

## Edge cases

- **Clock skew**: records may land with `system_from` slightly behind the watermark. Keep strict `>` and accept that they are caught on a later poll.
- **Bulk imports**: many records can share one `system_from`. Keep polling while `hasMore` is true.
- **Watermark in the future**: the client misses records. A periodic full refresh (e.g. daily) is a safety net.
