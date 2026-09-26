---
name: precommit
description: Running precommit checks and build validation. ALWAYS use after ANY code changes.
---

# Precommit and Build Validation

## Battery check

Skip the build on battery power. Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/precommit/SKILL.md` file.

```bash
<plugin-root>/scripts/check-battery || { echo "⚡ Skipping precommit on battery power"; exit 0; }
git test run HEAD --retest --verbose --verbose
```

## Run precommit

Validate with `git test run HEAD --retest --verbose --verbose`, using a timeout of at least 10 minutes. It runs the test configured via `git test add`, typically formatting, builds, tests, and other checks.

- Commit staged, unstaged, and other uncommitted changes with the `git:commit` skill before running it. Don't wait for `git test run` to refuse the dirty tree.
- Never substitute `just precommit` or another direct build command. Running on the committed tree caches the result against the commit. An eager validation commit is fine; the caller can reset, squash, or fix it up later.
- Try `git test run` with permitted execution before requesting escalation; it refreshes the index and writes `.git/index.lock` before the configured command starts. If it succeeds, use that result.
- If the sandbox blocks it, request escalation only when the active policy allows it. Under `approval_policy=never`, don't request escalation or bypass the policy. If no permitted execution can complete the command, report committed-tree validation as blocked with the command and permission error. Other checks don't establish that committed-tree validation passed.

If `git test` is not configured for this repository, say so and suggest the `build:test-setup` skill.

## Fix failures

Fix the failures, then commit the fixes with `git add -u && git commit --fixup=HEAD` before retrying, because `git test run HEAD` refuses a dirty tree and the fixup folds into the original commit on the next rebase. Repeat until precommit exits 0.

## Report

Start the final message with one of:

- "⚡ **Skipped precommit checks (on battery power)**"
- "✅ **Precommit checks passed**"
- "✅ **Precommit checks passed** (after fixing [brief description])"
- "⛔ **Committed-tree validation blocked**": permissions prevent `git test run HEAD` and escalation is unavailable or denied. Include the command and permission error, and report other checks separately without claiming precommit passed.
