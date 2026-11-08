---
name: temporal-data
description: System-time versioned (temporal) table patterns. Use when working with system_from/system_to columns, as-of queries, non-destructive updates, or temporal migrations.
---

# Temporal Data Patterns

This skill covers system time (transaction time) only. For valid time and bitemporal patterns, see the [Liftwizard temporal docs](https://liftwizard.io/docs/temporal-data/temporal-data-overview) and the [Klass DSL](https://klass.cool).

## Core Principles

- **Immutability**: writes are append-only, except for `system_to`.
- **Contiguous timeline**: a new row's `system_from` equals the old row's `system_to`, forming an unbroken chain of versions per entity.
- **Far-future sentinel over NULL**: use a far-future value (`9999-12-31 23:59:59.999`, or `253402300799999` as epoch milliseconds) for open-ended records. This allows NOT NULL constraints, composite primary keys, and uniform queries.
- **Sub-second precision**: store `system_from` and `system_to` with millisecond precision or finer. Two versions of one entity within the same unit of precision share a `system_from` and collide on the unique index, and upstream timestamps such as JavaScript's `Date.now()` and Reladomo's `TIMESTAMP` are already in milliseconds. Whole seconds are acceptable only when writes to one entity are guaranteed to be at least a second apart.
- **Deduplication**: before a phase-out / phase-in, compare incoming data with the current row and leave it untouched if unchanged. Adjacent identical rows produce false changes in history queries and diffs.
- **Universal**: every table is temporal by default. Temporality sits outside the domain model, so rollback restores everything (data, settings, account state) to the same instant. The only exceptions are the two in [Exceptions to universal temporality](#exceptions-to-universal-temporality).
- **No JSON columns**: model every field as a typed column or child table, including upstream fields the app does not read yet. Unread fields point at unimplemented features.
- **One timestamp per unit of work**: the application takes the current UTC time once per logical unit of work and stamps every `system_from`/`system_to` it writes with that identical value, even when the ORM splits the unit across several transactions (a self-referential hierarchy, a bulk update). The database does not issue timestamps.
- **No artificial ordering**: two units may share a timestamp, and timestamps need not increase in commit order; units that take different amounts of time land out of order. Never bump a timestamp (for example `max(now, last + 1)`) to make it unique or monotonic.

## Exceptions to universal temporality

There are two legitimate exceptions. Anything else is temporal, including reference data that merely never changes in practice. A table such as a game-version list is better temporal than exempt: it costs two columns, and relying on an upstream never mutating its identifiers is a promise this schema cannot enforce.

### Derivable caches

A table whose rows are computed from other temporal tables, such as a per-entity count of current child rows, may be a plain table. It is a cache, rebuilt on demand and never a source of truth. This holds only while every query asks about now. If the value must also be queryable as of an earlier instant, the cache is part of the history and must be temporal like everything else. Before building one, measure whether a view or a query over the temporal tables is already fast enough.

### Content-addressed composites

A composite whose identity is a hash of its content is immutable by construction: the same key can never hold different content, so there is no version to record and nothing to phase out. A blueprint string keyed by the SHA-1 of the string is one, and the tables derived by parsing it (parsed game data, icons, recipes, entities) belong to the same composite and are exempt with it. Rows of a content-addressed composite are only inserted, never updated. Anything that merely references the composite by hash, such as the blueprint that points at a string, is an ordinary temporal table.

## Schema Design

Every temporal table has `system_from` (when this version became current, set by the application) and `system_to` (when it was superseded, defaulting to the far-future sentinel), both NOT NULL.

### Primary key on `(id, system_to)` or `(id, system_from)`, unique index on the other

Either works, and they are equivalent as long as the other pair has a unique index. The `(id, system_to)` constraint is the one that catches a bug that creates two current rows for one ID: all current rows share `system_to = FAR_FUTURE_DATE`, so the second insert fails immediately. Reladomo puts the PK on `(id, system_to)`. The `(id, system_to)` index also serves the most common query, finding the current version.

### Timestamp encoding

Pick one encoding for every temporal table, with millisecond precision or finer:

| Encoding               | Column type | Sentinel                  | Notes                                                                                                                                                  |
| ---------------------- | ----------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Epoch milliseconds     | `INTEGER`   | `253402300799999`         | Cheapest to compare, index and bind, and identical to JavaScript `Date.now()`. Unreadable in raw queries unless paired with the derived columns below. |
| ISO text with fraction | `TEXT`      | `9999-12-31 23:59:59.999` | Readable as stored and sorts correctly, provided every value has the same width and fraction digits.                                                   |

The query and DDL examples below use the whole-second text form `9999-12-31 23:59:59` to keep them short. Substitute your encoding's sentinel and comparison values.

### Human-readable derived columns

With epoch milliseconds, add generated `VIRTUAL` columns that render each timestamp as text. They cost no storage, they appear in `SELECT *` and in the database console, and the application never writes them.

```sql
CREATE TABLE nodes (
  id TEXT NOT NULL,
  name TEXT,
  system_from INTEGER NOT NULL, -- set by the application, once per unit of work
  system_to INTEGER NOT NULL DEFAULT 253402300799999,
  system_from_text TEXT GENERATED ALWAYS AS (strftime('%Y-%m-%d %H:%M:%f', system_from / 1000.0, 'unixepoch')) VIRTUAL,
  system_to_text TEXT GENERATED ALWAYS AS (strftime('%Y-%m-%d %H:%M:%f', system_to / 1000.0, 'unixepoch')) VIRTUAL,
  PRIMARY KEY (id, system_to)
);
```

The sentinel renders as `9999-12-31 23:59:59.999`. SQLite rejects an `INSERT` or `UPDATE` that names a generated column, so a writer cannot set them by mistake. Never filter or join on them; compare the integer columns. Columns added later with `ALTER TABLE ... ADD COLUMN` must be `VIRTUAL`.

An ORM can ignore them by leaving them out of its table definition, in which case they need a hand-written migration. Or it can declare them so migrations create them. In Drizzle:

```typescript
systemFromText: text('system_from_text').generatedAlwaysAs(
	sql`strftime('%Y-%m-%d %H:%M:%f', system_from / 1000.0, 'unixepoch')`,
	{mode: 'virtual'},
),
```

Drizzle's SQLite generated-column support needs `drizzle-orm` 0.32 or later and `drizzle-kit` 0.23 or later. Cloudflare D1 supports generated columns, but verify that `drizzle-kit` emits `VIRTUAL` ones for D1 with your versions. An alternative with no schema footprint is a read-only view that adds the text columns.

### Example DDL

```sql
CREATE TABLE nodes (
  id TEXT NOT NULL,
  name TEXT,
  system_from TEXT NOT NULL, -- set by the application, once per unit of work
  system_to TEXT NOT NULL DEFAULT '9999-12-31 23:59:59',
  PRIMARY KEY (id, system_to)
);

CREATE UNIQUE INDEX nodes_system_from_idx ON nodes(id, system_from);
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
SELECT *, strftime('%Y-%m-%d %H:%M:%f', 'now'), '9999-12-31 23:59:59.999'
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

Apply both operations to every table, including settings and account state, so the whole database returns to the same instant:

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

## Derived Data

Data rebuilt entirely from temporal tables (full-text search indexes, caches, materialized views) may be non-temporal. Rebuild it after a rollback instead of rolling it back. Framework bookkeeping such as a migrations table is not data and is exempt.

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

Take the timestamp in application code once per unit of work (for example `new Date()` formatted as UTC) and pass it to every insert and update in that unit. Do not keep a clock table or let the database default `system_from`.

## Testing

Test as-of queries at version boundaries; off-by-one errors there are common.
