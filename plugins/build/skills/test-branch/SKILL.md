---
name: test-branch
description: Test every commit in the current branch with git-test, delegate failures to a fix subagent, fold the fixes in with test-fix, and loop until all commits pass. Use when asked to test or fix the branch.
---

# Test Branch

Run the test-fix loop for the current branch against upstream until every commit passes. Fixing is delegated to a subagent so the main thread stays on the loop.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/test-branch/SKILL.md` file.

## Setup

```bash
WORKDIR=$(mkdir -p .llm && mktemp -d .llm/test-branch.XXXX)
```

Initialize `${WORKDIR}/report.md`:

```markdown
# Test Branch Report

Started: [timestamp]
```

Allow at most 10 iterations.

## Loop

Each iteration runs these phases in order.

### Run test-branch

Redirect output to a file, since build logs can exceed 10K lines. Use a 30-minute timeout; if it expires, stop with "Stopped: timeout".

```bash
<plugin-root>/scripts/test-branch > "${WORKDIR}/build.log" 2>&1; echo $?
```

The script writes the branch name to `JUSTFILE_BRANCH` (test-fix reads it) and runs `git test run --retest --verbose --verbose` over `${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}..<branch>`. Exit 0 means all commits pass: go to **Done**.

### Check for auto-formatted changes

If `git status --porcelain` shows local changes, the pre-commit hook already auto-formatted files and there is nothing to fix. Skip to test-fix.

### Fix the failing commit

The failing commit is HEAD, since git-test checks out each commit; get it with `git log --oneline -1` and append the iteration to the report. If the same commit failed in the previous iteration, stop with "Stopped: same commit failed twice".

If the auto-format check found no changes, launch a subagent with this prompt instead of fixing the errors yourself:

```text
Use the build:fix skill to fix the build error toward the end of: ${WORKDIR}/build.log
```

Wait for it, then go straight to test-fix without committing.

### Run test-fix

Use a 30-minute timeout; if it expires, stop with "Stopped: timeout".

```bash
<plugin-root>/scripts/test-fix > "${WORKDIR}/test-fix.log" 2>&1; echo $?
```

The script stages the changes, runs pre-commit on them, creates a fixup commit for HEAD, refuses to continue if anything is still uncommitted, replays the `JUSTFILE_BRANCH` branch onto the fixup, autosquashes it into the failing commit, and reruns test-branch on all commits.

Exit 0 means all commits pass: go to **Done**. Non-zero means the retest found more failures: loop back to run test-branch rather than stopping.

## Done

Append the result to the report and display the full report.

## Report format

Append each iteration as it happens:

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

- Always display the report when stopping.
- Never run `git test forget-results`; the cache lets git-test skip already-passing commits.
- Never rebase manually or resolve conflicts yourself; only `<plugin-root>/scripts/test-fix` rebases.
