---
name: precommit
description: Running precommit checks and build validation using just commands. Use when validating code changes, running tests, or fixing build failures.
---

# Precommit and Build Validation

This skill provides guidelines for running precommit checks, testing builds, and fixing failures.

## Running Precommit Checks

🔧 Run `just precommit` to validate code before committing:

- Use a timeout of at least 10 minutes
- If it fails, analyze the errors and fix them directly
- Do not commit the changes when done (that's handled separately)

This command typically runs:

- Linters and formatters
- Type checkers
- Unit tests
- Build processes

## Testing All Commits

Run `just --global-justfile test-branch` on all commits in the current branch. When a build failure occurs, fix the error, create a fixup commit, rebase, and retry until all commits pass.

### Overview

This automates the test-fix loop:

1. Run `just --global-justfile test-branch` to test each commit
2. If a commit fails:
   - Extract the error from the build output
   - Fix the error
   - Run `just --global-justfile test-fix` to create fixup commit and rebase
   - Repeat from step 1
3. If all commits pass, report success

### Execution Loop

1. **Start the test run in background**:
   - Run `just --global-justfile test-branch` with `run_in_background: true`
   - Save the shell ID for monitoring

2. **Monitor the output**:
   - Use `BashOutput` with a filter regex to capture only relevant lines:
     - Filter: `"FAILURE|SUCCESS|ERROR|error:|warning:|✗|BAD COMMIT|GOOD COMMIT|Recipe.*failed"`
   - Poll periodically until the shell completes
   - Accumulate the filtered output

3. **When the shell completes**:
   - If exit code is 0:
     - Report: "✅ All commits pass!"
     - Exit
   - If exit code is non-zero:
     - Filtered output now contains errors but not the full build log
     - Fix the error based on the filtered output
     - The current git status
     - The commit SHA that failed (visible in the "BAD COMMIT" line)

4. **Handle the fix**:
   - If you cannot fix without user input:
     - Show the error to the user
     - Ask: "I need help fixing this error. Should I: (a) Skip this commit, (b) Wait for you to fix it manually, or (c) Try a different approach?"
     - Exit and let the user decide
   - If you successfully fixed the code:
     - Verify there are unstaged changes with `git status --porcelain`
     - Run `just --global-justfile test-fix` (NOT in background)
     - Go back to step 1

5. **Safety limit**: If more than 10 iterations occur, report: "⚠️ Too many iterations. Please review manually." and exit

### Important Notes

- The `BashOutput` filter is critical: it extracts errors without consuming the entire build log
- Each fix should use fresh context
- You may need user input; respect that and exit gracefully
- Do NOT commit anything yourself; the `test-fix` command handles that
- Use `KillShell` if you need to abort a running background shell
