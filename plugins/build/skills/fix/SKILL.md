---
name: fix
description: Run git-test precommit checks and fix failures without committing, or fix the errors described in a provided build log. Use when asked to fix build, test, lint, typecheck, or precommit failures.
---

# Fix

🔧 Run precommit and fix any failures that occur. Do not commit the changes when done.

## 📄 Existing Error Context

If the user provides error context (a build log path, a pasted error, or a description of the failure), skip running precommit entirely. Read the referenced context; for a log file, inspect the last 200 lines and strip ANSI codes. Identify the errors and fix them directly. Do not run precommit afterward; the caller handles verification.

## ⚙️ Running Precommit

When no error context is provided, run this command to validate code:

```bash
git test run HEAD --retest --verbose --verbose
```

- Use a timeout of at least 10 minutes
- This command runs the test configured via `git test add` (typically autoformatting, builds, tests, and other quality checks)
- This always runs the build, even on battery power. The `build:precommit` skill skips the build on battery, but invoking this skill is an explicit request to fix the build, so that gate does not apply here.

## 📋 Handle Missing Configuration

If `git test` is not configured for this repository, clearly explain the situation and suggest the `build:test-setup` skill to configure it.

## ❌ Handle Check Failures

When precommit fails (due to: type checking errors, test failures, linting issues, build errors):

- Analyze the error output to understand what failed
- Fix the specific failures
- Run precommit again. Once fixes are in the working tree, `git test run HEAD` refuses the dirty tree, so re-run without a commit argument: `git test run --retest --verbose --verbose` tests the working copy (its result is not cached)
- Continue the fix-and-retry cycle until precommit completes successfully with exit code 0

Do not commit the fixes, and do not create fixup commits. Callers such as the `build:test-branch` skill run the plugin's `scripts/test-fix`, which stages the working tree and runs `git commit --fixup HEAD` itself, so it expects the fixes to be left uncommitted.

## ✅ Reporting Results

Your final message must start with one of:

- "✅ Precommit checks passed" - if ran successfully
- "✅ Precommit checks passed (after fixing [brief description])" - if fixed issues
- "✅ Fixed errors from provided context ([brief description])" - if fixed errors from the provided context without running precommit
