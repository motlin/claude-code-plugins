# justfile-utils

Utilities for working with justfiles, including doc comment optimization.

## Commands

### `/justfile-recipe-short-doc`
Shorten justfile recipe doc comments for simple single-line recipes by making the doc comment match the command exactly.

Before:
```justfile
# Install dependencies
install:
    npm install
```

After:
```justfile
# npm install
install:
    npm install
```

Only applies to recipes that are a single line of ~120 characters or less.
