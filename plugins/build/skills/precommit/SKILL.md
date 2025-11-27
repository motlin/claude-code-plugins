---
name: precommit
description: Running precommit checks and build validation. ALWAYS use after ANY code changes.
---

# Precommit and Build Validation

See [shared/precommit-instructions.md](../../shared/precommit-instructions.md) for execution details on how to validate changes after they are written.

## Commands and Agents

| Task                    | Use                                                    |
| ----------------------- | ------------------------------------------------------ |
| Run precommit and fix   | `/build:fix` command or `build:precommit-runner` agent |
| Test all branch commits | `/build:test-branch` command                           |
| Test and autosquash     | `build:build-fixer-autosquash` agent                   |
