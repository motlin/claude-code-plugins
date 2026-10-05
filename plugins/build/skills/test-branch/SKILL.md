---
name: test-branch
description: Test every commit in the current branch with git-test, delegate failures to a fix subagent, fold the fixes in with test-fix, and loop until all commits pass. Use when asked to test or fix the branch.
---

# Test Branch

Run the test-fix loop for the current branch against upstream until every commit passes. Fixing is delegated to a subagent so the main thread stays on the loop.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/test-branch/SKILL.md` file.

## Setup

```bash
BRANCH=$(git branch --show-current)
TESTS=${GIT_TESTS:-default}
WORKDIR=$(mkdir -p .llm && mktemp -d .llm/test-branch.XXXX)
```

Require a clean working tree and a named local branch before starting. If HEAD is detached, identify the intended branch before running tests. Capture `BRANCH` once and retain it across every retry; never replace it with the detached failing commit. Set `UPSTREAM_REMOTE` and `UPSTREAM_BRANCH` to the intended comparison ref and verify it exists.

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
<plugin-root>/scripts/test-branch "$BRANCH" "$TESTS" > "${WORKDIR}/build.log" 2>&1; echo $?
```

The script writes the branch name to `JUSTFILE_BRANCH` (test-fix reads it) and runs `git test run --retest --verbose --verbose` over `${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}..<branch>`. Exit 0 means all commits pass: go to **Done**.

`--retest` reruns cached failures but reuses cached successes; report cached results as cached, not as fresh executions. For a nonzero exit, inspect the log before treating HEAD as a failing commit. Continue the fix loop only when git-test identifies a bad commit in the saved branch range. Stop and report setup, permission, checkout, or other infrastructure errors as such.

### Check for auto-formatted changes

Inspect `git status --porcelain` and the diff. If the only changes are formatter repairs from this test run, proceed to test-fix. Local changes alone do not prove the build failure is fixed; investigate remaining errors and preserve unrelated work.

### Fix the failing commit

The failing commit is HEAD, since git-test checks out each commit; get it with `git log --oneline -1` and append the iteration to the report. If the same commit failed in the previous iteration, stop with "Stopped: same commit failed twice".

If errors remain beyond formatter repairs, launch a subagent with this prompt instead of fixing the errors yourself:

```text
Use the build:fix skill to fix the build error toward the end of: ${WORKDIR}/build.log
```

Wait for it, review the diff, and stage intended new files individually. Then go straight to test-fix without committing. Export `GIT_TESTS="$TESTS"` so the script retests the same test configuration.

### Run test-fix

Use a 30-minute timeout; if it expires, stop with "Stopped: timeout".

```bash
<plugin-root>/scripts/test-fix > "${WORKDIR}/test-fix.log" 2>&1; echo $?
```

The script validates the saved branch and detached failing commit, stages tracked repairs, and runs pre-commit with separate filename arguments. It retries hooks once after formatter edits; persistent hook or configuration errors stop before committing. It amends only the detached failing commit, preserving its message and author even when the repair leaves an empty commit. It then replays the saved branch's descendants onto the repair without changing its base or other branches, and retests that explicit branch. Existing fixup commits in the descendants are preserved.

Exit 0 means all commits pass: go to **Done**. Exit 2 means the repair workflow failed before retesting; stop and report the phase, current HEAD, branch, and remaining changes. For other nonzero exits, inspect the retest log: loop only if it identifies another bad commit. Do not count hook, commit, or replay failures as repeated test failures. Preserve the saved branch marker and detached repair for recovery; never blindly rerun test-fix on that repair. Git versions that cannot replay merge commits will stop during replay; do not flatten those merges to force success. A timeout always stops the loop.

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
- Never rewrite history manually or resolve conflicts yourself; only `<plugin-root>/scripts/test-fix` rewrites the tested branch.
