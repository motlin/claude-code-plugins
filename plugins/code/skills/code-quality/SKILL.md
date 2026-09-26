---
name: code-quality
description: Code quality guidelines. ALWAYS use skill for ANY code changes.
---

# Code Quality Guidelines

## Don't write forgiving code

- Accept one input format. In TypeScript, avoid union types (`|`).
- Validate inputs with preconditions or schema libraries. When expectations are violated, throw instead of logging.
- Don't add defensive try/catch blocks; let exceptions propagate.
- Delete legacy code paths instead of keeping them as compatibility fallbacks.

## Naming

Don't abbreviate: `number`, not `num`; `greaterThan`, not `gt`.

## Files

Confirm with the user before creating a new markdown file.

## Emoji

Emoji and unicode characters are welcome at the start of comments and in doc headers.
