---
name: comment-cleanup
description: Keep code comments concise and durable, or clean redundant comments without changing code behavior. Use when adding, editing, reviewing, or removing comments; after code changes; before committing; or when asked to clean comments in a diff or across the repository.
---

# Comment Guidelines

Use comments sparingly, for non-obvious logic, constraints, or business rules.

## Scope

Default to **diff-only cleanup**: inspect the complete staged and unstaged patch and edit only comments that patch introduced or changed. Unchanged comments in changed files are out of scope.

Use **repository-wide cleanup** only when the user asks to clean all comments, the whole repository, or a named directory. Then apply the same rules to existing comments in that scope.

## Remove

- Commented-out code.
- Comments that restate the code or the method name.
- Edit-history narration such as "added", "removed", "changed", "updated", or "now handles".

## Keep

- TODO, FIXME, and similar markers.
- Linter, formatter, compiler, coverage, and generated-code directives (`// prettier-ignore`, `// eslint-disable-next-line`, `// @ts-ignore`).
- Pre-existing comments during diff-only cleanup.
- Comments whose removal would leave an empty required scope, such as an empty catch or else block (`// deliberately empty`).

## Placement

Don't use end-of-line comments. Move a necessary one to its own line directly above the code it describes, at the same indentation.

Change only comments: not executable code, behavior, unrelated formatting, or generated files that should be regenerated instead.
