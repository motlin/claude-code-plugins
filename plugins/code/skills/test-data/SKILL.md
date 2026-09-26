---
name: test-data
description: Keep literal values in tests self-evidently fake. Use when writing, reviewing, or modifying test code that contains literal values like timestamps, names, IDs, paths, or URLs.
---

# Test Data Guidelines

Literal values in tests must be recognizable as fabricated. A reader should never wonder whether a value was copied from production.

## Timestamps

Use memorable boundary dates, not specific-looking times:

```text
# Bad: looks recorded from a real system
2023-11-14T22:13:20.000Z

# Good
1999-12-31T00:00:00.000Z
2000-01-01T00:00:00.000Z
```

## Names and identifiers

Use the Alice/Bob/Charlie series or obviously generic names, with `example.com` (reserved by RFC 2606) for email:

```text
# Bad: could be a real person, or the developer's own identity
user: "jsmith"
email: "john.smith@company.com"

# Good
user: "alice"
email: "alice@example.com"
```

## Numeric IDs

Use round numbers or boundary values, not arbitrary numbers that look like real database IDs:

```text
# Bad
id: 8847291

# Good
id: 100
id: 0
id: 2_147_483_647
id: 9_999_999
```

## Paths and URLs

No real usernames, home directories, or system paths:

```text
# Bad
path: "/Users/jsmith/.config/app/settings.json"

# Good
path: "/tmp/test/settings.json"
url: "https://example.com/api/v1/resource"
```
