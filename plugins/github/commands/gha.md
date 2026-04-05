---
description: Fix failing GitHub Actions for the current commit
---

🔧 Fix failing GitHub Actions for the current commit.

- 🔄 Run `git fetch` to get the latest refs from origin
- 🔍 Find the failing checks for the current commit
    - Use `gh run list --commit HEAD --limit 10` to see recent workflow runs
    - For failed runs, use `gh run view <run-id>` to see details
    - Use `gh run view <run-id> --log-failed` to see only failed job logs
- 🐛 Analyze the failure logs to understand what's broken
    - Look for test failures, build errors, linting issues, or type errors
- 🛠️ Fix the identified issues
- ✅ Verify fixes locally if possible
- 📤 Create a commit with the fixes
    - Stage only the files you modified to fix the CI issues
    - `git commit --fixup HEAD`
