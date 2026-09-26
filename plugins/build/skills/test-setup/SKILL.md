---
name: test-setup
description: Configure git-test for the current repository so the test-branch and test-all skills work. Use when git test is missing or the user asks to set up branch testing.
---

# Test Setup

Configure `git test` so the `build:test-branch` and `build:test-all` skills work.

## Check current state

Run `git test list`. If a test is already configured, show it and ask before replacing it.

## Detect project capabilities

```bash
ls justfile 2>/dev/null
just --list 2>/dev/null | grep precommit
which should-skip-commit 2>/dev/null
```

## Choose the test command

If a justfile with a `precommit` recipe exists, offer these with `AskUserQuestion`:

- **Standard (Recommended)**: clean-tree guards around `just precommit`, with skip logic

    ```bash
    just --global-justfile _check-local-modifications && (should-skip-commit || just precommit) && just --global-justfile _check-local-modifications
    ```

- **Without skip**: same guards, always runs precommit

    ```bash
    just --global-justfile _check-local-modifications && just precommit && just --global-justfile _check-local-modifications
    ```

- **Precommit with args**: ask which arguments to pass, then use

    ```bash
    just --global-justfile _check-local-modifications && just precommit <args> && just --global-justfile _check-local-modifications
    ```

Otherwise, tell the user that `build:test-branch` expects a `just precommit` recipe, and ask whether to configure a custom test command instead.

## Configure and verify

`--forget` clears stale cached results:

```bash
git test add --test default '<chosen command>' --forget
git test list
```

Show the `git test list` output to the user.
