---
name: code-quality
description: Code quality guidelines. ALWAYS use skill for ANY code changes.
---

# Code Quality Guidelines

## Don't write forgiving code

- Don't permit multiple input formats
  - In TypeScript, this means avoiding Union Type (the `|` in types)
- Use preconditions
  - Use schema libraries
  - Assert that inputs match expected formats
  - When expectations are violated, throw, don't log
- Don't add defensive try/catch blocks
  - Usually we let exceptions propagate out
- Don't keep legacy code paths as fallbacks
  - Remove old code instead of keeping it around for compatibility

## Naming Conventions

- Don't use abbreviations or acronyms
  - Choose `number` instead of `num` and `greaterThan` instead of `gt`

## File Management

- Prefer editing an existing file to creating a new one
- Confirm with the user before creating any new markdown files

## Style

- Emoji and unicode characters are welcome
  - Use them at the beginning of comments, commit messages, and in headers in docs
