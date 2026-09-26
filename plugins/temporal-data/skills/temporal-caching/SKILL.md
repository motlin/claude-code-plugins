---
name: temporal-caching
description: Efficient data loading patterns using system_from/system_to for cache validation. Use when implementing incremental sync, conditional fetches, polling for changes, ETags, high watermarks, or avoiding redundant data transfer in systems with temporal tables.
---

# Temporal Caching

In a system-time versioned table, `system_from` changes whenever a record changes, so it serves as a built-in cache validator. No separate version columns, ETag tables, or change tracking are needed. See the `temporal-data:temporal-data` skill for the underlying schema and query conventions.

| Pattern                                         | Mechanism                                                                        | Best for                                             |
| ----------------------------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------- |
| [Global watermark](./global-watermark.md)       | Client stores max `system_from` of a collection and polls for newer records      | Feeds, dashboards, "what's new since I last checked" |
| [Predicate watermark](./predicate-watermark.md) | Parent stores max `system_from` of its children in a denormalized column         | "Have any of this user's blueprints changed?"        |
| [Item watermark](./item-watermark.md)           | `system_from` of the current row is the ETag; server returns 304 when it matches | Single resources fetched repeatedly                  |
| Global + item                                   | Global for the list, item for detail views                                       | Feed page with detail drill-down                     |
