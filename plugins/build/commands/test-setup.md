---
description: Set up git test for the current project
---

Configure `git test` in the current repository so that `/build:test-branch` and `/build:test-all` work.

## Step 1: Check current state

Run `git test list` to see if git test is already configured. If it is, show the current configuration and ask the user if they want to reconfigure.

## Step 2: Detect project capabilities

Check:

1. Does a `justfile` exist in the project root? Run: `ls justfile 2>/dev/null`
2. Does the justfile have a `precommit` recipe? Run: `just --list 2>/dev/null | grep precommit`
3. Is `should-skip-commit` available? Run: `which should-skip-commit 2>/dev/null`

## Step 3: Choose the test command

Present the user with choices using `AskUserQuestion`. The options depend on what was detected:

**If justfile with `precommit` recipe exists:**

- **Standard (Recommended)**: `just --global-justfile _check-local-modifications && (should-skip-commit || just precommit) && just --global-justfile _check-local-modifications`
  - Wraps `just precommit` with clean-tree guards and skip logic
- **Without skip**: `just --global-justfile _check-local-modifications && just precommit && just --global-justfile _check-local-modifications`
  - Same but always runs precommit, never skips
- **Precommit with args**: Ask the user what arguments to pass to `just precommit <args>`, then use: `just --global-justfile _check-local-modifications && just precommit <args> && just --global-justfile _check-local-modifications`

**If no justfile or no `precommit` recipe:**

- Tell the user that `/build:test-branch` expects `just precommit` to exist
- Ask if they want to configure a custom test command instead

## Step 4: Configure git test

Run the chosen command with `--forget` to clear any stale cached results:

```bash
git test add --test default '<chosen command>' --forget
```

## Step 5: Verify

Run `git test list` to confirm the configuration was saved correctly. Show the output to the user.
