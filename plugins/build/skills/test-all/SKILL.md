---
name: test-all
description: Run git-test on every local branch that contains upstream, fix failures with the build-fixer-autosquash agent, and loop until all commits pass. Use when asked to run or fix test-all.
---

# Test All

Run tests on every commit of every local branch and fix failures in a loop.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/test-all/SKILL.md` file.

Run:

```bash
<plugin-root>/scripts/test-all
```

Use a long timeout of at least 30 minutes.

The script lists every local branch that contains `${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}` and runs `<plugin-root>/scripts/test-branch` on each, which writes the branch name to `JUSTFILE_BRANCH` and runs `git test run --retest --verbose --verbose` over the branch's commits. With the default `FAIL_FAST=false` it continues to the next branch after a failure, so inspect the output for failed branches rather than relying on the exit code alone; `FAIL_FAST=true` stops at the first failure. git-test checks out each commit it tests, so a failure leaves HEAD detached at the failing commit.

If any branch fails:

- Delegate the repair to the `build:build-fixer-autosquash` agent. It reads the branch from `JUSTFILE_BRANCH`, fixes the failure through the `build:precommit-runner` agent, creates a fixup commit, replays the branch onto it, and autosquashes non-interactively, using the `git:conflict-resolver` agent if the rebase conflicts. Do not fix the failure in the main thread and do not commit or rebase yourself; fixes made on git-test's detached HEAD without that replay would be stranded off the branch.
- Run `<plugin-root>/scripts/test-all` again. The script is smart and resumes from where it left off.
- Repeat until all tests pass.

Do not clear git-test cached results (never run `git test forget-results`); the cache is what lets the script skip already-passing commits.
