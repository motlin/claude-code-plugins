---
name: test-data
description: This skill should be used when writing, reviewing, or modifying test code that contains literal values like timestamps, names, IDs, paths, or URLs.
---

# Test Data Guidelines

## Test data must be self-evidently fake

Literal values in tests should be immediately recognizable as fabricated. A reader should never wonder whether a value was copied from production.

### Timestamps

Use memorable boundary dates, not specific-looking times that could be real:

```
# Bad — looks like it was recorded from a real system
2023-11-14T22:13:20.000Z

# Good — obviously a test value
1999-12-31T00:00:00.000Z
2000-01-01T00:00:00.000Z
```

### Names and identifiers

Use the conventional Alice/Bob/Charlie series, or obviously generic names:

```
# Bad — could be a real person, or the developer's own identity
user: "jsmith"
email: "john.smith@company.com"

# Good — conventional test names
user: "alice"
email: "alice@example.com"

# Also good
user: "bob"
email: "bob@example.com"
```

The `example.com` domain is reserved by IETF (RFC 2606) specifically for this purpose.

### Numeric IDs

Use round numbers or boundary values, not arbitrary numbers that look like real database IDs:

```
# Bad — looks like a real database ID
id: 8847291

# Good — round numbers
id: 100
id: 1000

# Good — boundary values
id: 0
id: 2_147_483_647
id: 9_999_999
```

### Paths and URLs

Don't use real usernames, home directories, or system paths. Use generic placeholders:

```
# Bad — contains a real username and home directory
path: "/Users/jsmith/.config/app/settings.json"

# Good
path: "/tmp/test/settings.json"
url: "https://example.com/api/v1/resource"
```
