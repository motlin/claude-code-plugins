---
description: Test each commit in the current branch with git-test, fix failures, and loop
---

Automate the test-fix loop for the current branch against upstream/main. Test each commit with git-test, fix failures, create fixup commits, and repeat until all commits pass.

## Setup

Initialize a report at `${TMPDIR}/report.md`:

```markdown
# Test Branch Report

Started: [timestamp]
```

Set `iteration = 0` and `max_iterations = 10`. Create a temp directory with `mktemp -d` and use it as `TMPDIR` for all temp files below.

## Loop

### Step 1: Run test-branch

Increment iteration. Redirect output to a temp file since build logs can be 10K+ lines:

```bash
just --global-justfile test-branch > ${TMPDIR}/build.log 2>&1; echo $?
```

Use a 10-minute timeout.

- Exit code 0: all commits pass. Go to **Done**.
- Non-zero: continue to Step 2.

### Step 2: Extract errors

Read the last 200 lines of `${TMPDIR}/build.log`:

```bash
tail -200 ${TMPDIR}/build.log | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g'
```

Identify the failing commit from the "BAD COMMIT" line. Append the iteration to the report.

### Step 3: Check for auto-formatted changes

Run `git status --porcelain`. If there are local changes, the pre-commit hook already auto-formatted files — there's nothing to fix. Skip straight to Step 4.

If there are no local changes, invoke `/build:fix` with the prompt: "The build error is near the end of ${TMPDIR}/build.log". This lets it skip re-running precommit and jump straight to fixing. Do not create commits -- test-fix handles that.

### Step 4: Run test-fix

```bash
just --global-justfile test-fix > ${TMPDIR}/test-fix.log 2>&1; echo $?
```

Use a 10-minute timeout. This stages changes, creates a fixup commit, rebases to squash it, then re-runs test-branch on all commits.

- Exit code 0: all commits pass. Go to **Done**.
- Non-zero: display the report, tell the user test-fix failed, and stop. The user can inspect `${TMPDIR}/test-fix.log` and re-invoke this command to continue.

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
- If the same commit fails twice, stop
- Always display the report when stopping
