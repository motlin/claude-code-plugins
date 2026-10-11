---
name: gha
description: Debug and fix failing GitHub Actions checks for the current commit. Use when asked to fix CI, GHA, or GitHub Actions failures.
---

# GitHub Actions Fix

Use the `code:cli`, `git:git-workflow`, and `git:commit` skills when available.

Run `git fetch`, then find the failing runs for `HEAD` and read their logs:

```bash
gh run list --commit HEAD --limit 10
gh run view <run-id>
gh run view <run-id> --log-failed
```

Fix the failures and reproduce and verify the fix locally; if the failure can't be reproduced locally (e.g. it depends on CI-only secrets or runners), say so in the report. Stage only the files changed to fix CI, then commit:

```bash
git commit --fixup HEAD
```
