---
name: github-actions-fix
description: Debug and fix failing GitHub Actions checks for the current commit. Use when asked to fix CI, GHA, or GitHub Actions failures.
---

# GitHub Actions Fix

Use the `code:cli`, `git-workflow`, and `git-commit` skills when available.

## Fetch Latest Refs

Run:

```bash
git fetch
```

## Find Failing Checks

Inspect recent workflow runs for `HEAD`:

```bash
gh run list --commit HEAD --limit 10
```

For failed runs:

```bash
gh run view <run-id>
gh run view <run-id> --log-failed
```

## Fix Failures

Analyze the failure logs. Look for test failures, build errors, lint errors, type errors, missing dependencies, or environment issues.

Fix the identified issue and verify locally when practical.

## Commit

Stage only files modified to fix CI and create a fixup commit:

```bash
git commit --fixup HEAD
```

Never stage unrelated files.
