---
name: build-fix
description: Commit changes, run git-test precommit checks, and fix failures. Use when asked to fix build, test, lint, typecheck, or precommit failures.
---

# Build Fix

Commit the changes under test, run precommit, and fix any failures.

## Existing Error Context

If the user provides an error log or path, read the referenced context first. If it is a log file, inspect the last 200 lines and strip ANSI codes when needed. Fix those errors directly, then continue through the commit and verification workflow.

## Commit Changes

Use the `git-commit` skill to commit all changes in scope before running precommit. `git test run HEAD` validates a commit and refuses to run on a dirty tree.

## Run Precommit

When no error context is provided, run:

```bash
git test run HEAD --retest --verbose --verbose
```

Use a timeout of at least 10 minutes.

If `git test` is not configured, explain that and suggest the `build-test-setup` skill.

## Fix Loop

When checks fail:

- Analyze the error output.
- Fix the specific failures.
- Commit the fixes with a fixup commit for `HEAD` before retrying.
- Re-run precommit.
- Continue until precommit succeeds.

## Reporting

Start the final response with one of:

- `Precommit checks passed`
- `Precommit checks passed (after fixing <brief description>)`
