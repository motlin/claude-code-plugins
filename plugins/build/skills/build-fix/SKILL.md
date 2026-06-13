---
name: build-fix
description: Run git-test precommit checks and fix failures without committing. Use when asked to fix build, test, lint, typecheck, or precommit failures.
---

# Build Fix

Run precommit and fix any failures. Do not commit changes.

## Existing Error Context

If the user provides an error log or path, read the referenced context first. If it is a log file, inspect the last 200 lines and strip ANSI codes when needed. Fix those errors directly and do not run precommit afterward unless the user asks; the caller handles verification.

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
- Re-run precommit.
- Continue until precommit succeeds.

## Reporting

Start the final response with one of:

- `Precommit checks passed`
- `Precommit checks passed (after fixing <brief description>)`
- `Fixed errors from provided context (<brief description>)`

Do not commit the changes.
