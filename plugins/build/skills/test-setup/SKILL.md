---
name: test-setup
description: Configure git-test for the current repository so the test-branch and test-all skills work. Use when git test is missing or the user asks to set up branch testing.
---

# Test Setup

Configure `git test` in the current repository so that the `build:test-branch` and `build:test-all` skills work.

## Check Current State

Run:

```bash
git test list
```

If it is already configured, show the current configuration and ask the user whether to reconfigure before replacing it.

## Detect Project Capabilities

Check whether a `justfile` exists in the project root, whether it has a `precommit` recipe, and whether `should-skip-commit` is available:

```bash
ls justfile 2>/dev/null
just --list 2>/dev/null | grep precommit
which should-skip-commit 2>/dev/null
```

## Choose Test Command

Present the choices with `AskUserQuestion`. The options depend on what was detected.

If a justfile with a `precommit` recipe exists, offer three options:

- **Standard (Recommended)**: wraps `just precommit` with clean-tree guards and skip logic

    ```bash
    just --global-justfile _check-local-modifications && (should-skip-commit || just precommit) && just --global-justfile _check-local-modifications
    ```

- **Without skip**: same guards, but always runs precommit and never skips

    ```bash
    just --global-justfile _check-local-modifications && just precommit && just --global-justfile _check-local-modifications
    ```

- **Precommit with args**: ask the user what arguments to pass to `just precommit <args>`, then use

    ```bash
    just --global-justfile _check-local-modifications && just precommit <args> && just --global-justfile _check-local-modifications
    ```

If no justfile or no `just precommit` recipe exists, tell the user that the `build:test-branch` skill expects `just precommit` to exist and branch testing needs a reliable test command, and ask whether they want to configure a custom test command instead.

## Configure

Run the chosen command with `--forget` to clear any stale cached results:

```bash
git test add --test default '<chosen command>' --forget
```

## Verify

Confirm the configuration was saved correctly and show the output to the user:

```bash
git test list
```
