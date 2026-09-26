---
name: test-all
description: Run git-test on every local branch that contains upstream, fix failures with the build-fixer-autosquash agent, and loop until all commits pass. Use when asked to run or fix test-all.
---

# Test All

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/test-all/SKILL.md` file.

Run with a timeout of at least 30 minutes:

```bash
<plugin-root>/scripts/test-all
```

The script runs `<plugin-root>/scripts/test-branch` on every local branch that contains `${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}`. That writes the branch name to `JUSTFILE_BRANCH` and runs `git test run --retest --verbose --verbose` over the branch's commits. With the default `FAIL_FAST=false` it continues past failures, so read the output for failed branches instead of trusting the exit code; `FAIL_FAST=true` stops at the first failure. A failure leaves HEAD detached at the failing commit.

When a branch fails, delegate the repair to the `build:build-fixer-autosquash` agent, which fixes the failure, creates a fixup commit, replays the branch onto it, and autosquashes. Don't fix, commit, or rebase in the main thread: fixes made on git-test's detached HEAD without that replay are stranded off the branch. Then rerun `<plugin-root>/scripts/test-all`, which resumes where it left off, and repeat until everything passes.

Never run `git test forget-results`; the cache lets the script skip already-passing commits.
