---
name: build-test-setup
description: Configure git-test for the current repository. Use when git test is missing or the user asks to set up branch testing.
---

# Build Test Setup

Configure `git test` in the current repository.

## Check Current State

Run:

```bash
git test list
```

If it is already configured, show the current configuration and ask before replacing it.

## Detect Project Capabilities

Check:

```bash
ls justfile 2>/dev/null
just --list 2>/dev/null | grep precommit
which should-skip-commit 2>/dev/null
```

## Choose Test Command

If a justfile with a `precommit` recipe exists, prefer:

```bash
just --global-justfile _check-local-modifications && (should-skip-commit || just precommit) && just --global-justfile _check-local-modifications
```

Other acceptable options:

```bash
just --global-justfile _check-local-modifications && just precommit && just --global-justfile _check-local-modifications
```

or a user-supplied `just precommit <args>` variant.

If no justfile or no `precommit` recipe exists, explain that branch testing expects a reliable test command and ask for the command to use.

## Configure

Run:

```bash
git test add --test default '<chosen command>' --forget
```

Then verify with:

```bash
git test list
```
