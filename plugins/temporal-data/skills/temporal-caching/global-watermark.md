# Global Watermark

The client stores a single timestamp — the maximum `system_from` seen across all records in a collection. On each poll, it queries for records newer than that timestamp. If nothing comes back, nothing changed.

## Server Side

### Query: fetch records newer than watermark

```sql
SELECT * FROM blueprints
WHERE system_from > @high_watermark
  AND system_to = '9999-12-31 23:59:59'
ORDER BY system_from DESC
LIMIT @page_size;
```

This returns only current records (`system_to = FAR_FUTURE`) that were created or updated after the client's watermark. The `system_from > @high_watermark` condition is strict (not `>=`) to avoid re-fetching the record that set the watermark.

### Detecting deletions

In a temporal table, "deleting" a record means setting `system_to` to the current timestamp. The record is no longer current, but the phase-out doesn't change `system_from` — it changes `system_to`. A global watermark query on `system_from` alone will miss deletions.

Two approaches:

**Option A: Query both created and phased-out records**

```sql
-- New or updated records
SELECT id, 'upsert' AS change_type, * FROM blueprints
WHERE system_from > @high_watermark AND system_to = '9999-12-31 23:59:59';

-- Phased-out (deleted) records
SELECT id, 'delete' AS change_type FROM blueprints
WHERE system_to > @high_watermark AND system_to != '9999-12-31 23:59:59';
```

**Option B: Dedicated change log table**

```sql
CREATE TABLE change_log (
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  change_type TEXT NOT NULL,  -- 'upsert' or 'delete'
  changed_at TEXT NOT NULL,
  PRIMARY KEY (entity_type, entity_id, changed_at)
);
```

### REST endpoint

```
GET /api/blueprints?since=2024-06-15T14:30:00Z&limit=100
```

Returns an array of changed records plus metadata:

```json
{
  "data": [...],
  "_metadata": {
    "highWatermark": "2024-06-15T15:00:00Z",
    "hasMore": false
  }
}
```

The server computes `highWatermark` as the max `system_from` in the result set. The client stores this for the next poll.

## Client Side

### Storage

Store the watermark durably — localStorage for browsers, a database row for backend services:

```typescript
interface HighWatermarkData {
  lastSystemFrom: string; // ISO timestamp
  lastChecked: number; // Date.now() of last poll
}
```

### Polling loop

```typescript
async function pollForChanges(watermark: string): Promise<ChangeResult> {
  const response = await fetch(`/api/blueprints?since=${watermark}&limit=100`);
  const { data, _metadata } = await response.json();

  if (data.length === 0) {
    // Nothing changed — no cache invalidation needed
    return { changed: false, newWatermark: watermark };
  }

  // Advance the watermark
  return { changed: true, data, newWatermark: _metadata.highWatermark };
}
```

### Cache invalidation

When new records arrive, invalidate or update the relevant client-side caches:

```typescript
if (result.changed) {
  saveWatermark(result.newWatermark);
  queryClient.invalidateQueries({ queryKey: ["blueprints"] });
}
```

### Initial load (no watermark yet)

On first load, the client has no watermark. Fetch the full first page normally and seed the watermark from the results:

```typescript
const maxSystemFrom = Math.max(
  ...records.map((r) => new Date(r.systemFrom).getTime()),
);
saveWatermark(new Date(maxSystemFrom).toISOString());
```

## Real-World Example: Factorio Prints

[Factorio Prints](https://www.factorio.school) implements this pattern to keep its blueprint feed current without re-fetching the entire list.

**Server query** (`fetchSummariesNewerThan` in `src/api/firebase.ts`):

```typescript
const summariesQuery = query(
  ref(db, "/blueprintSummaries/"),
  orderByChild("lastUpdatedDate"),
  startAt(highWatermark + 1),
  limitToLast(100),
);
```

**Client polling** (`useHighWatermarkSync` in `src/hooks/useHighWatermarkSync.ts`):

- Polls every 5 minutes via React Query's `refetchInterval`
- Reads the stored watermark from localStorage
- If new summaries arrive, advances the watermark and invalidates the paginated query cache
- If no new summaries, returns `[]` — no UI update, no wasted bandwidth

**Watermark seeding** (`useRawPaginatedBlueprintSummaries`):

- On each page load, extracts `Math.max(...lastUpdatedDate)` and calls `updateHighWatermark()`
- `updateHighWatermark` only advances (never goes backward)

## Edge Cases

- **Clock skew**: If server clocks are not synchronized, records may appear to have `system_from` values in the past relative to the watermark. Use strict `>` (not `>=`) and accept that briefly-skewed records will be caught on the next poll cycle.
- **Bulk imports**: A bulk import may create many records with the same `system_from`. The limit/pagination in the query handles this — if `hasMore` is true, the client should continue polling.
- **Watermark corruption**: If the stored watermark is somehow in the future, the client will miss records. Consider a periodic full refresh (e.g., daily) as a safety net.
