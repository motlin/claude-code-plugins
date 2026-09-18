---
name: test-branch
description: Test every commit in the current branch with git-test, delegate failures to a fix subagent, fold the fixes in with test-fix, and loop until all commits pass. Use when asked to test or fix the branch.
---

# Test Branch

Automate the test-fix loop for the current branch against the upstream branch. Test each commit, fix failures, create fixup commits, and repeat until all commits pass. Keep the main thread focused on the loop; fixing is delegated to a subagent.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/test-branch/SKILL.md` file.

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

The phases below run in order on every iteration: run test-branch, check for auto-formatted changes, identify the failing commit and fix it, run test-fix.

### Run test-branch

Increment the iteration. Redirect output to a file since build logs can be 10K+ lines:

```bash
<plugin-root>/scripts/test-branch > "${WORKDIR}/build.log" 2>&1; echo $?
```

The script writes the branch name to `JUSTFILE_BRANCH` (test-fix reads it later) and runs `git test run --retest --verbose --verbose` over `${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}..<branch>`. Use a 30-minute timeout. If the timeout expires, stop and display the report with "Stopped: timeout".

- Exit code 0: all commits pass. Go to **Done**.
- Non-zero: continue to the auto-format check.

### Check for auto-formatted changes

Run `git status --porcelain`. If there are local changes, the pre-commit hook already auto-formatted files and there is nothing to fix. Skip straight to test-fix.

### Identify the failing commit and fix it

The failing commit is HEAD (git-test checks out each commit). Get it with `git log --oneline -1`. Append the iteration to the report. If this is the same commit that failed in the previous iteration, stop and display the report with "Stopped: same commit failed twice".

When the auto-format check found no local changes, launch a **subagent** to fix the errors. Do NOT fix them yourself; delegate so the main thread stays focused on the loop. Give the subagent this prompt:

```
Use the build:fix skill to fix the build error toward the end of: ${WORKDIR}/build.log
```

Wait for the subagent to complete, then proceed immediately to test-fix. Do not create commits; test-fix handles that.

### Run test-fix

```bash
<plugin-root>/scripts/test-fix > "${WORKDIR}/test-fix.log" 2>&1; echo $?
```

Use a 30-minute timeout. If the timeout expires, stop and display the report with "Stopped: timeout".

The script stages the changes, runs pre-commit on them, creates a fixup commit for HEAD, refuses to continue if anything is still uncommitted, replays the branch recorded in `JUSTFILE_BRANCH` onto the fixup, rebases with `--autosquash` onto the upstream branch to squash it into the failing commit, and then re-runs test-branch on all commits.

- Exit code 0: all commits pass. Go to **Done**.
- Non-zero: **loop back to run test-branch**. The re-test found more failures; continue the loop. Do NOT stop here.

## Done

Append success to the report. Display the full report.

## Report Format

Append each iteration to the report as it happens:

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
- NEVER run `git test forget-results`; the cache is the whole point of git-test, letting it skip already-passing commits
- NEVER rebase manually; only `<plugin-root>/scripts/test-fix` does rebasing. Do not attempt to resolve conflicts or work around failures yourself.
