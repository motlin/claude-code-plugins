---
allowed-tools: Task, Bash(just:*), Bash(git:*), BashOutput, KillShell
description: Test all commits and fix errors in a loop
---

Run `just --global-justfile test-branch` on all commits in the current branch. When a build failure occurs, use a fresh subagent to fix the error, create a fixup commit, rebase, and retry until all commits pass.

## Overview

This command automates the test-fix loop:
1. Run `just --global-justfile test-branch` to test each commit
2. If a commit fails:
   - Extract the error from the build output
   - Launch a subagent to fix the error
   - Run `just --global-justfile test-fix` to create fixup commit and rebase
   - Repeat from step 1
3. If all commits pass, report success

## Task

Execute the following loop:

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
     - Filtered output now contains errors but not the full 10MB+ log
     - Use the Task tool to launch the `test-branch-fixer` agent with:
       - The filtered error output
       - The current git status
       - The commit SHA that failed (visible in the "BAD COMMIT" line)
     - Wait for the agent to complete

4. **Handle the agent result**:
   - If the agent reports it cannot fix without user input:
     - Show the error to the user
     - Ask: "I need help fixing this error. Should I: (a) Skip this commit, (b) Wait for you to fix it manually, or (c) Try a different approach?"
     - Exit and let the user decide
   - If the agent successfully fixed the code:
     - Verify there are unstaged changes with `git status --porcelain`
     - Run `just --global-justfile test-fix` (NOT in background)
     - Go back to step 1

5. **Safety limit**: If more than 10 iterations occur, report: "⚠️ Too many iterations. Please review manually." and exit

## Notes

- The `BashOutput` filter is critical: it extracts errors without consuming the entire build log
- Each fix uses a fresh subagent for clean context
- The agent may report it needs user input; respect that and exit gracefully
- Do NOT commit anything yourself; the `test-fix` command handles that
- Use `KillShell` if you need to abort a running background shell
