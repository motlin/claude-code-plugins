---
name: justfile-style
description: Style guidelines for justfile recipe documentation. Use when writing or editing justfiles to keep recipe doc comments consistent and concise.
---

# Justfile Style

## Doc comments for short recipes

When a recipe body is a single line of roughly 120 characters or less, make its doc comment the command itself instead of a descriptive phrase. The command tells the reader exactly what runs.

Before:

```justfile
# Install dependencies
[group('setup')]
install:
    npm install
```

After:

```justfile
# npm install
[group('setup')]
install:
    npm install
```

Keep a descriptive doc comment for shebang recipes, multi-line recipes, and single-line commands longer than about 120 characters.
