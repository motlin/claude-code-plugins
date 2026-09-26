---
name: temporal-data
description: Temporal database patterns for system-time versioned tables. Use when working with tables that have system_from/system_to columns, temporal queries, non-destructive updates, merge/sync logic, rollback, or schema migrations involving temporal data.
---

# Temporal Data Patterns

This skill covers system time (transaction time) only. For valid time and bitemporal patterns, see the [Liftwizard temporal docs](https://liftwizard.io/docs/temporal-data/temporal-data-overview) and the [Klass DSL](https://klass.cool).

## Core Principles

- **Immutability**: writes are append-only, except for `system_to`.
- **Contiguous timeline**: a new row's `system_from` equals the old row's `system_to`, forming an unbroken chain of versions per entity.
- **Far-future sentinel over NULL**: use `9999-12-31 23:59:59` for open-ended records. This allows NOT NULL constraints, composite primary keys, and uniform queries.
- **Deduplication**: before a phase-out / phase-in, compare incoming data with the current row and leave it untouched if unchanged. Adjacent identical rows produce false changes in history queries and diffs.

## Schema Design

Every temporal table has `system_from` (when this version became current, defaulting to now) and `system_to` (when it was superseded, defaulting to the far-future sentinel), both NOT NULL.

### Primary key on `(id, system_to)`

This is the Reladomo convention. All current rows share `system_to = FAR_FUTURE_DATE`, so a bug that creates two current rows for one ID fails immediately with a PK violation. With `(id, system_from)`, that bug only surfaces if both rows have the exact same start timestamp, so it goes undetected.

If both constraints are needed, put the PK on one and a unique index on the other. The `(id, system_to)` index serves the most common query, finding the current version.

### Example DDL

```sql
CREATE TABLE nodes (
  id TEXT NOT NULL,
  name TEXT,
  system_from TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
  system_to TEXT NOT NULL DEFAULT '9999-12-31 23:59:59',
  PRIMARY KEY (id, system_to)
);

CREATE INDEX nodes_system_from_idx ON nodes(id, system_from);
```

### Adding Temporal Columns to Existing Table

SQLite requires recreating the table to change the primary key:

```sql
CREATE TABLE my_table_new (
  id TEXT NOT NULL,
  -- existing columns...
  system_from TEXT NOT NULL,
  system_to TEXT NOT NULL DEFAULT '9999-12-31 23:59:59',
  PRIMARY KEY (id, system_to)
);

INSERT INTO my_table_new
SELECT *, strftime('%Y-%m-%d %H:%M:%S', 'now'), '9999-12-31 23:59:59'
FROM my_table;

DROP TABLE my_table;
ALTER TABLE my_table_new RENAME TO my_table;

CREATE INDEX my_table_system_from_idx ON my_table(id, system_from);
```

For databases that support `ALTER TABLE ... ADD PRIMARY KEY`, this is simpler:

```sql
ALTER TABLE my_table ADD COLUMN system_from TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE my_table ADD COLUMN system_to TIMESTAMP NOT NULL DEFAULT '9999-12-31 23:59:59';
ALTER TABLE my_table DROP PRIMARY KEY;
ALTER TABLE my_table ADD PRIMARY KEY (id, system_to);
CREATE INDEX my_table_system_from_idx ON my_table(id, system_from);
```

After migration, update application code to add `WHERE system_to = '9999-12-31 23:59:59'` to all existing queries.

## Query Patterns

### Current Records

```sql
SELECT * FROM nodes WHERE system_to = '9999-12-31 23:59:59';

-- For a specific entity
SELECT * FROM nodes WHERE id = ? AND system_to = '9999-12-31 23:59:59';
```

### As-Of Query (Point-in-Time)

Use `system_from <= T AND system_to > T`:

```sql
SELECT * FROM nodes
WHERE id = ?
  AND system_from <= '2024-06-15 14:30:00'
  AND system_to > '2024-06-15 14:30:00';
```

Exactly one row matches at any instant. Never use `BETWEEN` for as-of queries: with contiguous timestamps it matches two rows at each boundary.

### History of an Entity

```sql
SELECT * FROM nodes WHERE id = ? ORDER BY system_from DESC;
```

### Entities Changed in a Range

```sql
SELECT DISTINCT id FROM nodes
WHERE system_from >= '2024-01-01' AND system_from <= '2024-12-31';
```

## Write Operations

### Phase Out and Replace (Non-Destructive Update)

```sql
-- Step 1: Close the current version
UPDATE nodes
SET system_to = '2024-06-15 14:30:00'
WHERE id = 'node-1' AND system_to = '9999-12-31 23:59:59';

-- Step 2: Insert the new version
INSERT INTO nodes (id, name, system_from, system_to)
VALUES ('node-1', 'New Name', '2024-06-15 14:30:00', '9999-12-31 23:59:59');
```

The new row's `system_from` must equal the old row's `system_to` to maintain a contiguous timeline. Both statements must run in the same transaction.

### Non-Destructive Delete

Phase out without inserting a replacement:

```sql
UPDATE nodes
SET system_to = '2024-06-15 14:30:00'
WHERE id = 'node-1' AND system_to = '9999-12-31 23:59:59';
```

## Merge List Pattern (Three-Way Sync)

When syncing from an external source into a temporal cache, implement all three legs:

```
External Source         Cache (temporal)
+-------------+         +-------------+
| A (updated) |         | A (old)     |  <- LEG 1: Update
| B (same)    |         | B (same)    |  <- LEG 1: Leave untouched
| C (new)     |         | D (deleted) |  <- LEG 2: Insert C
+-------------+         +-------------+  <- LEG 3: Phase out D
```

- **Leg 1, in both**: if the data changed, phase out and insert; if unchanged, do nothing.
- **Leg 2, only in source**: insert with `system_from = now`, `system_to = FAR_FUTURE_DATE`.
- **Leg 3, only in cache**: phase out.

```sql
UPDATE nodes
SET system_to = @now
WHERE system_to = '9999-12-31 23:59:59'
  AND id NOT IN (SELECT id FROM source_ids);
```

Leg 3 is the most commonly forgotten. Without it, deleted items stay in the cache forever, the cache grows unbounded, and stale data causes errors when writing back to the source.

Wrap all three legs in one transaction, and make sure an empty source list phases out every cached record.

Bulk imports use the same compare-before-cut logic, and can report each record as added, updated, unchanged, or deleted.

## Multi-Table / Parent-Child

Each temporal table tracks its own `system_from`/`system_to`. Don't derive a child's `system_to` by joining on the parent's `system_from`: with deduplication, the parent row may not change when only child data changes, and vice versa.

All tables edited in one transaction use the same timestamp, so an as-of query at that timestamp returns a coherent snapshot.

Each new version copies the unchanged columns. Consider splitting very wide, rarely changing columns into a separate table to reduce duplication.

## Temporal Rollback (Disaster Recovery)

Apply both operations to every table:

```sql
-- 1. Purge: Delete rows created after the rollback point
DELETE FROM nodes WHERE system_from > @target_timestamp;

-- 2. Restore: Re-open rows that were current at the rollback point
UPDATE nodes
SET system_to = '9999-12-31 23:59:59'
WHERE system_from <= @target_timestamp
  AND system_to > @target_timestamp;
```

This is destructive and violates immutability. Use it only for disaster recovery.

## Composites

A composite is an entity spanning multiple tables, e.g. a `Blueprint` composite of `Blueprint`, `BlueprintTag`, and `ImgurImage`.

Ownership direction matters. `BlueprintTag` belongs to the `Blueprint` composite, not the `Tag` composite: a tag is standalone, and `BlueprintTag` is a join table owned by `Blueprint`. Editing any part of a composite bumps the whole composite's version once, so a `BlueprintTag` change bumps the `Blueprint` version, not the `Tag` version. Ownership determines which version table a write updates and which tables participate in as-of-by-version queries.

## Versioning

A separate version table tracks version numbers with their own `system_from`/`system_to`:

```sql
CREATE TABLE question_version (
  question_id BIGINT NOT NULL,
  number INTEGER NOT NULL,
  system_from TIMESTAMP NOT NULL,
  system_to TIMESTAMP NOT NULL DEFAULT '9999-12-31 23:59:59',
  PRIMARY KEY (question_id, system_to)
);
```

The version table is the entry point for as-of-by-version queries: look up the version's `system_from`, then run as-of queries at that timestamp on every table in the composite.

```sql
-- Step 1: Find the timestamp for version 1
SELECT system_from FROM question_version
WHERE question_id = ? AND number = 1;

-- Step 2: Use that timestamp for as-of queries on all related tables
SELECT * FROM question
WHERE id = ? AND system_from <= @version_timestamp AND system_to > @version_timestamp;

SELECT * FROM question_tag
WHERE question_id = ? AND system_from <= @version_timestamp AND system_to > @version_timestamp;
```

## Auditing

Auditing records who made each change, and builds on temporal support.

```sql
CREATE TABLE question (
  id BIGINT NOT NULL,
  title TEXT,
  body TEXT,
  created_by_id TEXT NOT NULL,
  created_on TIMESTAMP NOT NULL,
  last_updated_by_id TEXT NOT NULL,
  system_from TIMESTAMP NOT NULL,
  system_to TIMESTAMP NOT NULL DEFAULT '9999-12-31 23:59:59',
  PRIMARY KEY (id, system_to)
);
```

`created_by_id` and `created_on` are set once on creation. `last_updated_by_id` changes with each version. Put these columns on both the main table and the version table.

## Optimistic Locking

Edit APIs take the version number as input and reject the edit with a conflict error when it doesn't match the current version.

## Framework-Specific Patterns

### Klass DSL

The [Klass](https://klass.cool) DSL uses classifier modifiers as compiler macros:

```klass
class Question
    systemTemporal
    versioned
    audited
{
    id   : Long key;
    title: String;
    body : String;
}
```

`systemTemporal` infers `system`/`systemFrom`/`systemTo` properties. `versioned` infers a version class. `audited` infers `createdById`/`createdOn`/`lastUpdatedById` properties.

### Reladomo (Liftwizard)

[Liftwizard](https://liftwizard.io) uses [Reladomo](https://github.com/goldmansachs/reladomo) for temporal support. Reladomo manages `system_from`/`system_to` through `AsOfAttribute` declarations in XML object definitions, and handles phase-out / phase-in, contiguous timelines, and as-of queries.

See [Liftwizard temporal documentation](https://liftwizard.io/docs/temporal-data/temporal-data-overview) for non-destructive updates, as-of queries, versioning, auditing, optimistic locking, diffs, and maker/checker workflows.

### Drizzle ORM (TypeScript/SQLite)

```typescript
import {sqliteTable, text, primaryKey, uniqueIndex} from 'drizzle-orm/sqlite-core';

export const nodes = sqliteTable(
	'nodes',
	{
		id: text('id').notNull(),
		name: text('name'),
		systemFrom: text('system_from').notNull(),
		systemTo: text('system_to').notNull().default('9999-12-31 23:59:59'),
	},
	(table) => ({
		pk: primaryKey({columns: [table.id, table.systemTo]}),
		systemFromIdx: uniqueIndex('nodes_system_from_idx').on(table.id, table.systemFrom),
	}),
);
```

## Testing

Test as-of queries at version boundaries; off-by-one errors there are common.
