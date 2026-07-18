---
name: comment-cleanup
description: Keep code comments concise and durable, or clean redundant comments without changing code behavior. Use when adding, editing, reviewing, or removing comments; after code changes; before committing; or when asked to clean comments in a diff or across the repository.
---

# Comment Guidelines

Use comments sparingly. Preserve comments that explain non-obvious logic, constraints, or business rules.

## Choose cleanup scope

Default to **diff-only cleanup**. Inspect the complete staged and unstaged patch and edit only comments introduced or changed by that patch. Looking at every changed file is too broad because unchanged comments in those files are outside scope.

Use **repository-wide cleanup** only when the user explicitly asks to clean all comments, the whole repository, or a named directory. In repository-wide mode, apply the same rules to existing comments inside the requested scope.

## Remove comment clutter

- Delete commented-out code.
- Delete comments that merely restate the code or method name.
- Delete edit-history narration using terms such as "added", "removed", "changed", "updated", or "now handles".
- Remove redundant comments without hesitation when the code is already self-explanatory.

## Preserve necessary comments

- Preserve TODO, FIXME, and similar work markers.
- Preserve linter, formatter, compiler, coverage, and generated-code directives.
- Preserve non-obvious reasoning and business rules.
- Preserve pre-existing comments during diff-only cleanup.
- Do not remove a comment when doing so would leave an invalid or empty required scope.

## Place comments cleanly

Do not use end-of-line comments. Move a necessary end-of-line comment to its own line immediately above the code it describes, using the same indentation.

Focus only on comments. Do not change executable code, behavior, formatting unrelated to the moved or removed comment, or generated files that should be regenerated instead.
