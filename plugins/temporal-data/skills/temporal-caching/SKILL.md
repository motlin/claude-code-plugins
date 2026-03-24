---
name: temporal-caching
description: Efficient data loading patterns using system_from/system_to for cache validation. Use when implementing incremental sync, conditional fetches, polling for changes, ETags, high watermarks, or avoiding redundant data transfer in systems with temporal tables.
---

# Temporal Caching

System-time versioned tables give you a built-in cache validator: `system_from` changes whenever a record is updated. This eliminates the need for separate version columns, ETags tables, or change-tracking infrastructure.

Three patterns leverage this at different granularities:

## Global Watermark

Client stores the maximum `system_from` seen across an entire collection. On each poll, asks "give me everything newer than X." Empty result means nothing changed — no data transfer needed.

**Best for:** feeds, dashboards, lists sorted by recency where you need to detect _any_ change across a large collection.

[Full pattern →](./global-watermark.md)

## Predicate Watermark

The "one" side of a one-to-many relationship stores the maximum `system_from` of its children as a denormalized column. Clients can check this single value before deciding whether to fetch the entire child collection.

**Best for:** parent-child relationships where fetching all children is expensive but checking the parent is cheap.

[Full pattern →](./predicate-watermark.md)

## Item Watermark

Client sends the last-known `system_from` for a specific item in the request header. Server returns HTTP 304 if the item hasn't changed. Maps directly to standard HTTP conditional request semantics (ETags).

**Best for:** individual resource endpoints where clients repeatedly fetch the same item.

[Full pattern →](./item-watermark.md)

## Choosing a Pattern

| Scenario                                      | Pattern             | Why                                            |
| --------------------------------------------- | ------------------- | ---------------------------------------------- |
| "Show me what's new since I last checked"     | Global watermark    | One query covers the whole collection          |
| "Have any of this user's blueprints changed?" | Predicate watermark | Avoids fetching all blueprints to find out     |
| "Give me blueprint X if it changed"           | Item watermark      | Standard HTTP caching for single resources     |
| Feed page with detail drill-down              | Global + Item       | Global for the list, item for individual views |
