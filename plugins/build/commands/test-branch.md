---
description: Test every commit in the current branch, fix failures, and loop until all pass
---

Automates the test-fix loop for the current branch against the upstream branch. Tests each commit, fixes failures, creates fixup commits, and repeats until all commits pass.

## Setup

Create a temp directory and set `WORKDIR` to it:

```bash
WORKDIR=$(mktemp -d)
```

Initialize a report at `${WORKDIR}/report.md`:

```markdown
# Test Branch Report

Started: [timestamp]
```

Set `iteration = 0` and `max_iterations = 10`.

## Loop

### Step 1: Run test-branch

Increment iteration. Redirect output to a temp file since build logs can be 10K+ lines:

```bash
just --global-justfile test-branch > ${WORKDIR}/build.log 2>&1; echo $?
```

Use a 10-minute timeout. If the timeout expires, stop and display the report with "Stopped: timeout".

- Exit code 0: all commits pass. Go to **Done**.
- Non-zero: continue to Step 2.

### Step 2: Check for auto-formatted changes

Run `git status --porcelain`. If there are local changes, the pre-commit hook already auto-formatted files — there's nothing to fix. Skip straight to Step 3.

### Step 2b: Identify failing commit and fix

The failing commit is HEAD (git-test checks out each commit). Get it with `git log --oneline -1`. Append the iteration to the report. If this is the same commit that failed in the previous iteration, stop and display the report with "Stopped: same commit failed twice".

If there are no local changes (Step 2 found nothing), invoke `/build:fix Fix the build error toward the end of: ${WORKDIR}/build.log`. This skips re-running precommit since the errors are already captured. Do not create commits — test-fix handles that.

### Step 3: Run test-fix

```bash
just --global-justfile test-fix > ${WORKDIR}/test-fix.log 2>&1; echo $?
```

Use a 10-minute timeout. If the timeout expires, stop and display the report with "Stopped: timeout".

This stages changes, creates a fixup commit, rebases to squash it into the failing commit, then re-runs test-branch on all commits.

- Exit code 0: all commits pass. Go to **Done**.
- Non-zero: display the report, tell the user test-fix failed, and stop. The user can inspect `${WORKDIR}/test-fix.log` and re-invoke this command to continue.

## Done

Append success to the report. Display the full report.

## Report Format

```markdown
## Iteration 1

**Failing commit:** [short SHA] [subject]
**Error:** [1-2 line summary]
**Fix:** [what changed]
**Files:** [list]

## Result

**All commits pass after N iterations** or **Stopped: [reason]**
Completed: [timestamp]
```

## Safety

- Maximum 10 iterations
- Always display the report when stopping
- NEVER run `git test forget-results` — the cache is the whole point of git-test, letting it skip already-passing commits
