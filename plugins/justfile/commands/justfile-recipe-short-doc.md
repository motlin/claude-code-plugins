---
allowed-tools: Read, Edit, Glob
description: Shorten justfile recipe doc comments for simple recipes
---

For very short justfile recipes, change the doc comment string to be the entire command. Before:

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

- The cutoff for when to perform this refactoring should be approximately a single line of 120 characters.
- If the recipe is a shebang recipe, don't shorten the doc comment
- If the recipe is mutiple lines, or longer than 120 characters, don't shorten the doc comment
