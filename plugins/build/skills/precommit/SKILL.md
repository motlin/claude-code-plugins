---
name: precommit
description: Running precommit checks and build validation. ALWAYS use after ANY code changes.
---

# Precommit and Build Validation

@../../shared/precommit-instructions.md

## Agents

| Task                    | Use                                  |
|-------------------------|--------------------------------------|
| Run precommit and fix   | `build:precommit-runner` agent       |
| Test all branch commits | `/build:test-branch` command         |
| Test and autosquash     | `build:build-fixer-autosquash` agent |
