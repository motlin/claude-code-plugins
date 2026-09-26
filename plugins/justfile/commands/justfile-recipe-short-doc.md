---
description: Shorten justfile recipe doc comments for simple recipes
model: haiku
---

Apply the short-recipe doc comment rule from the `justfile:justfile-style` skill: for each recipe whose body is a single line of roughly 120 characters or less, replace the doc comment with the command itself.

```justfile
# npm install
[group('setup')]
install:
    npm install
```

Leave shebang recipes, multi-line recipes, and longer commands unchanged.
