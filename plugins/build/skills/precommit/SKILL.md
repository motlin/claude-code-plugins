---
name: precommit
description: Running precommit checks and build validation. ALWAYS use after ANY code changes.
---

# Precommit and Build Validation

## 🔋 Battery Check

**CRITICAL**: Before running any build or test commands, check if the machine is on battery power:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-battery || { echo "⚡ Skipping precommit on battery power"; exit 0; }
git test run HEAD --retest --verbose --verbose
```

- If on battery power, skip the build and report: "⚡ **Skipped precommit checks (on battery power)**"
- If on AC power, proceed with the build

## ⚙️ Running Precommit

Run `git test run HEAD --retest --verbose --verbose` to validate code:

- Use a timeout of at least 10 minutes
- This command runs the test configured via `git test add` (typically autoformatting, builds, tests, and other quality checks)

## 📋 Handle Missing Configuration

If `git test` is not configured for this repository, clearly explain the situation and suggest running `/build:test-setup` to configure it.

## ❌ Handle Check Failures

When precommit fails (due to: type checking errors, test failures, linting issues, build errors):

- Analyze the error output to understand what failed
- Fix the specific failures
- Run the precommit command again
- Continue the fix-and-retry cycle until precommit completes successfully with exit code 0

## ✅ Reporting Results

Your final message MUST start with one of:

- "⚡ **Skipped precommit checks (on battery power)**" - if skipped due to battery
- "✅ **Precommit checks passed**" - if ran successfully
- "✅ **Precommit checks passed** (after fixing [brief description])" - if fixed issues

## Agents

| Task                    | Use                                  |
| ----------------------- | ------------------------------------ |
| Run precommit and fix   | `build:precommit-runner` agent       |
| Test all branch commits | `/build:test-branch` command         |
| Test and autosquash     | `build:build-fixer-autosquash` agent |
