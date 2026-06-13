---
name: build-test-branch
description: Test every commit in the current branch, fix failures, create fixup commits, and repeat until all commits pass.
---

# Build Test Branch

Test each commit in the current branch against the upstream branch. Keep the main thread focused on the loop; use a subagent for failure fixing only when the user explicitly asks for subagents.

## Setup

Create a temp work directory:

```bash
WORKDIR=$(mktemp -d)
```

Create `${WORKDIR}/report.md` and record the start timestamp. Use `iteration = 0` and `max_iterations = 10`.

## Run Test Branch

Increment the iteration and run:

```bash
just --global-justfile test-branch > "${WORKDIR}/build.log" 2>&1; echo $?
```

Use a 30-minute timeout.

- Exit code 0: all commits pass.
- Non-zero: inspect the failure and continue.

## Fix Failure

Check for auto-formatted changes:

```bash
git status --porcelain
```

If files changed, continue to test-fix. If there are no changes, identify the failing commit with:

```bash
git log --oneline -1
```

If the same commit failed in the previous iteration, stop and show the report.

Fix the error near the end of `${WORKDIR}/build.log` using the `build-fix` skill. Do not create commits manually.

## Run Test Fix

Run:

```bash
just --global-justfile test-fix > "${WORKDIR}/test-fix.log" 2>&1; echo $?
```

Use a 30-minute timeout.

- Exit code 0: all commits pass.
- Non-zero: loop back to test-branch.

Never run `git test forget-results`. Never rebase manually; `test-fix` owns the rebase/autosquash step.

## Report

Show the failing commit, error summary, fix summary, changed files, and final result.
