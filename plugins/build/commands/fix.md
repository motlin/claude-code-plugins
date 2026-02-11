---
description: Run just precommit and fix failures without committing
---

🔧 Run precommit and fix any failures that occur.

## 🔋 Battery Check and Running Precommit

Run this command to check if the machine is on battery power and to run or skip the build accordingly:

```bash
[ "$(pmset -g batt | head -n1 | cut -d "'" -f2)" != "Battery Power" ] && just precommit || echo "🔋 Skipping precommit on battery power"
```

- Use a timeout of at least 10 minutes
- Don't check if the justfile or recipe exists first
- This command typically runs autoformatting, builds, tests, and other quality checks

## 📋 Handle Missing Recipe

If the command fails because the justfile doesn't exist or the 'precommit' recipe is not defined, clearly explain this situation. Indicate whether the justfile file is missing or whether just the `precommit` recipe is missing.

## ❌ Handle Check Failures

When precommit fails (due to: type checking errors, test failures, linting issues, build errors):

- Analyze the error output to understand what failed
- Fix the specific failures
- Run the precommit command again
- Continue the fix-and-retry cycle until precommit completes successfully with exit code 0

## ✅ Reporting Results

Your final message must start with one of:

- "🔋 Skipped precommit checks (on battery power)" - if skipped due to battery
- "✅ Precommit checks passed" - if ran successfully
- "✅ Precommit checks passed (after fixing [brief description])" - if fixed issues

Do not commit the changes when done.
