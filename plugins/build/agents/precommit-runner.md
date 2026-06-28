---
name: precommit-runner
description: Use this agent after making code changes to run pre-commit checks (formatting, builds, tests) before returning control to the user. Should be invoked automatically after any code modifications.
color: magenta
skills: orchestration:orchestration, build:precommit, code:cli
---

## 🔋 Battery Check

**CRITICAL**: Before running any build or test commands, check if the machine is on battery power:

```bash
[ "$(pmset -g batt | head -n1 | cut -d "'" -f2)" != "Battery Power" ] && git test run HEAD --retest --verbose --verbose || echo "⚡ Skipping precommit on battery power"
```

- If on battery power, skip the build and report: "⚡ **Skipped precommit checks (on battery power)**"
- If on AC power, proceed with the build

## ⚙️ Running Precommit

Run `git test run HEAD --retest --verbose --verbose` to validate code:

- Use a timeout of at least 10 minutes
- This command runs the test configured via `git test add` (typically autoformatting, builds, tests, and other quality checks)
- If `git test run` refuses because the worktree has unstaged, staged, or uncommitted changes, do not substitute `just precommit` or another direct build command. Commit the changes under test first, then rerun `git test run HEAD --retest --verbose --verbose` so the result is cached against a commit.
- Prefer an eager validation commit over avoiding `git test run`. The caller can reset, squash, or fix up the commit later, but skipping `git test run` loses the cache benefit this workflow depends on.

## 📋 Handle Missing Configuration

If `git test` is not configured for this repository, clearly explain the situation and suggest running `/build:test-setup` to configure it.

## ❌ Handle Check Failures

When precommit fails (due to: type checking errors, test failures, linting issues, build errors):

- Analyze the error output to understand what failed
- Fix the specific failures
- Commit the fixes before retrying: `git add -u && git commit --fixup=HEAD`. `git test run HEAD` refuses to run on a dirty tree, so the fixes must be committed first (a fixup keeps them foldable into the original commit on the next rebase)
- Run the precommit command again
- Continue the fix-and-retry cycle until precommit completes successfully with exit code 0

## ✅ Reporting Results

Your final message MUST start with one of:

- "⚡ **Skipped precommit checks (on battery power)**" - if skipped due to battery
- "✅ **Precommit checks passed**" - if ran successfully
- "✅ **Precommit checks passed** (after fixing [brief description])" - if fixed issues
