---
name: precommit
description: Running precommit checks and build validation. ALWAYS use after ANY code changes.
---

# Precommit and Build Validation

## 🔋 Battery Check

**CRITICAL**: Before running any build or test commands, check if the machine is on battery power.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/precommit/SKILL.md` file.

```bash
<plugin-root>/scripts/check-battery || { echo "⚡ Skipping precommit on battery power"; exit 0; }
git test run HEAD --retest --verbose --verbose
```

- If on battery power, skip the build and report: "⚡ **Skipped precommit checks (on battery power)**"
- If on AC power, proceed with the build

## ⚙️ Running Precommit

Run `git test run HEAD --retest --verbose --verbose` to validate code:

- Use a timeout of at least 10 minutes
- This command runs the test configured via `git test add` (typically autoformatting, builds, tests, and other quality checks)
- Before invoking `git test run`, commit unstaged, staged, or uncommitted changes with the `git-commit` skill. Do not wait for `git test run` to refuse the dirty tree.
- Do not substitute `just precommit` or another direct build command. Run `git test run HEAD --retest --verbose --verbose` on the committed tree so the result is cached against the commit.
- Prefer an eager validation commit over avoiding `git test run`. The caller can reset, squash, or fix up the commit later, but skipping `git test run` loses the cache benefit this workflow depends on.
- In sandboxed environments, request escalation for `git test run`; it refreshes the index and writes `.git/index.lock` before the configured command starts.

## 📋 Handle Missing Configuration

If `git test` is not configured for this repository, clearly explain the situation and suggest using the `build-test-setup` skill to configure it.

## ❌ Handle Check Failures

When precommit fails (due to: type checking errors, test failures, linting issues, build errors):

- Analyze the error output to understand what failed
- Fix the specific failures
- Commit the fixes before retrying: `git add -u && git commit --fixup=HEAD`. `git test run HEAD` refuses to run on a dirty tree, so the fixes must be committed first and the fixup keeps them foldable into the original commit on the next rebase.
- Run the precommit command again
- Continue the fix-and-retry cycle until precommit completes successfully with exit code 0

## ✅ Reporting Results

Your final message MUST start with one of:

- "⚡ **Skipped precommit checks (on battery power)**" - if skipped due to battery
- "✅ **Precommit checks passed**" - if ran successfully
- "✅ **Precommit checks passed** (after fixing [brief description])" - if fixed issues

## Related Workflows

| Task                    | Use                       |
| ----------------------- | ------------------------- |
| Run precommit and fix   | `build-fix` skill         |
| Test all branch commits | `build-test-branch` skill |
| Test and autosquash     | `build-test-all` skill    |
