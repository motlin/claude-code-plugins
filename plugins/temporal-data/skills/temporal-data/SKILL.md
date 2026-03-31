---
name: temporal-data
description: Temporal database patterns for system-time versioned tables. Use when working with tables that have system_from/system_to columns, temporal queries, non-destructive updates, merge/sync logic, rollback, or schema migrations involving temporal data.
---

# Temporal Data Patterns

Patterns for implementing temporal databases with system-time versioning.

## Temporal Dimensions

Temporal databases track data along one or two time dimensions:

- **System time** (transaction time): When the database recorded the fact. Managed automatically; never user-editable. This is the focus of this skill.
- **Valid time** (business time): When the fact was true in reality. Application-managed; can be backdated or future-dated.
- **Bitemporal**: Both dimensions. Enables "what did the database think at time T1 about the state at time T2?"

This skill covers **system time only**. For valid time and bitemporal patterns, see [Liftwizard temporal docs](https://liftwizard.io/docs/temporal-data/temporal-data-overview) and the [Klass DSL](https://klass.cool).

## Core Principles

- **Immutability**: All writes into the data store are immutable and append-only, except for the `system_to` value.
- **Contiguous timeline**: `system_from` of a new row equals `system_to` of the old row. This forms an unbroken chain of versions per entity.
- **Far-future sentinel over NULL**: Use a far-future date (e.g. `9999-12-31 23:59:59`) instead of NULL for open-ended records. Enables NOT NULL constraints, composite primary keys, and uniform query syntax.
- **Deduplication**: Before performing a phase-out/phase-in, compare the incoming data with the current row. If unchanged, leave the row untouched. This avoids creating adjacent rows with identical data for different time ranges, which would produce false changes in history queries and diffs.

## Schema Design

### Temporal Columns

Every temporal table has two additional columns:

| Column        | Semantics                        | Default                        |
| ------------- | -------------------------------- | ------------------------------ |
| `system_from` | When this version became valid   | Current timestamp (NOT NULL)   |
| `system_to`   | When this version was superseded | Far-future sentinel (NOT NULL) |

### Primary Key

Include a temporal column in the primary key to allow multiple versions per entity.

**Recommended: PK on `(id, system_to)`** (Reladomo convention)

The rationale is bug detection: current records all share `system_to = FAR_FUTURE_DATE`, so a bug that creates duplicate "current" records for the same ID triggers an immediate PK violation. With `(id, system_from)`, duplicate-current-record bugs only surface if two records have the exact same start timestamp — unlikely, so bugs go undetected.

If both constraints are needed, use PK on one and a unique index on the other.

### Indexes

Every temporal table needs an index on `(id, system_to)` for the most common query pattern: finding the current version via `WHERE id = ? AND system_to = FAR_FUTURE_DATE`.

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

**Use strict inequality: `system_from <= T AND system_to > T`**

```sql
SELECT * FROM nodes
WHERE id = ?
  AND system_from <= '2024-06-15 14:30:00'
  AND system_to > '2024-06-15 14:30:00';
```

This ensures exactly one row matches at any point in time. When rows have contiguous timestamps (`system_to` of row N = `system_from` of row N+1), `<=` on both sides (`BETWEEN`) would match two rows at the boundary. The strict `>` on `system_to` prevents this.

**WRONG: Do not use BETWEEN for as-of queries.**

```sql
-- WRONG: matches two rows at boundary timestamps
WHERE system_from BETWEEN '2024-01-01' AND '2024-12-31'
```

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

**When syncing from an external source to a temporal cache, implement ALL THREE legs:**

```
External Source         Cache (temporal)
+-------------+         +-------------+
| A (updated) |         | A (old)     |  <- LEG 1: Update
| B (same)    |         | B (same)    |  <- LEG 1: Leave untouched
| C (new)     |         | D (deleted) |  <- LEG 2: Insert C
+-------------+         +-------------+  <- LEG 3: Phase out D
```

### Leg 1: Sync Existing (matching IDs in both source and cache)

Compare data. If changed, phase out old version and insert new. If unchanged, leave untouched (do nothing).

### Leg 2: Add New (in source but not in cache)

Insert new records with `system_from = now`, `system_to = FAR_FUTURE_DATE`.

### Leg 3: Phase Out Orphaned (in cache but not in source) — COMMONLY FORGOTTEN

```sql
UPDATE nodes
SET system_to = @now
WHERE system_to = '9999-12-31 23:59:59'
  AND id NOT IN (SELECT id FROM source_ids);
```

### Common Bug: Missing Leg 3

The most common temporal sync bug is forgetting Leg 3. Symptoms:

- Deleted items remain in cache forever
- Cache grows unbounded
- Stale data causes errors when writing back to source

### Sync Checklist

Before considering a sync function complete:

- [ ] **Leg 1:** Updates existing records when data changes
- [ ] **Leg 2:** Inserts records not in cache
- [ ] **Leg 3:** Phases out cached records not in source
- [ ] Transaction wraps all three legs atomically
- [ ] Handles empty source list (phases out all cached records)

## Bulk Import Pattern

For large imports, use a two-phase approach:

**Phase 1:** Bulk phase-out all current records from the source scope (single UPDATE).

**Phase 2:** Process each imported record individually:

- If not phased out → new record, insert it
- If phased out and data matches → extend lifespan (undo phase-out)
- If phased out and data changed → insert new version

This pattern provides clear categorization: added / updated / unchanged / deleted.

## Temporal Rollback (Disaster Recovery)

To roll back the database to a previous point in time, apply two operations per table:

```sql
-- 1. Purge: Delete rows created after the rollback point
DELETE FROM nodes WHERE system_from > @target_timestamp;

-- 2. Restore: Re-open rows that were current at the rollback point
UPDATE nodes
SET system_to = '9999-12-31 23:59:59'
WHERE system_from <= @target_timestamp
  AND system_to > @target_timestamp;
```

This is a **destructive operation** that violates the immutability principle. Use only for disaster recovery.

## Versioning

When an entity is composed of multiple tables, editing ANY part of the composite bumps the version once. The version number applies to the entire composite, not individual tables.

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

Version numbers enable as-of queries by version instead of timestamp:

```sql
-- Find the timestamp for version 1
SELECT system_from FROM question_version
WHERE question_id = ? AND number = 1;

-- Use that timestamp for as-of queries on all related tables
SELECT * FROM question
WHERE id = ? AND system_from <= @version_timestamp AND system_to > @version_timestamp;
```

## Auditing

Auditing adds tracking of who made each change. Requires temporal support as a prerequisite.

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

- `created_by_id` and `created_on` are set once on creation and never change
- `last_updated_by_id` is updated on each new version
- These properties should appear on both the main table and the version table

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

[Liftwizard](https://liftwizard.io) uses [Reladomo](https://github.com/goldmansachs/reladomo) for temporal support. Reladomo manages `system_from`/`system_to` automatically through `AsOfAttribute` declarations in XML object definitions. The ORM handles phase-out/phase-in within transactions, contiguous timelines, and as-of query generation.

See [Liftwizard temporal documentation](https://liftwizard.io/docs/temporal-data/temporal-data-overview) for non-destructive updates, as-of queries, versioning, auditing, optimistic locking, diffs, and maker/checker workflows.

### Drizzle ORM (TypeScript/SQLite)

```typescript
import {
  sqliteTable,
  text,
  primaryKey,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";

export const nodes = sqliteTable(
  "nodes",
  {
    id: text("id").notNull(),
    name: text("name"),
    systemFrom: text("system_from").notNull(),
    systemTo: text("system_to").notNull().default("9999-12-31 23:59:59"),
  },
  (table) => ({
    pk: primaryKey({ columns: [table.id, table.systemTo] }),
    systemFromIdx: uniqueIndex("nodes_system_from_idx").on(
      table.id,
      table.systemFrom,
    ),
  }),
);
```

## Best Practices

- **Always use transactions** for temporal operations involving multiple statements
- **Compare data before inserting** to avoid duplicate versions when data hasn't changed
- **Index `(id, system_to)`** for current-record queries — this is the most important index
- **Monitor database size** — temporal tables grow with every change; implement lifespan extension to minimize bloat
- **Test as-of queries** to ensure correct temporal semantics — off-by-one at boundaries is a common bug
- **Use prepared statements** for better performance in bulk operations
