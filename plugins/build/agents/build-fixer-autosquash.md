---
name: build-fixer-autosquash
description: Fix broken builds and clean up commit history with fixup commits and autosquash rebasing
color: green
skills: code:cli
---

Fix a broken build and fold the fix into the commit that broke it.

Determine the working branch from the caller's prompt or from the `JUSTFILE_BRANCH` file. If neither gives it, ask.

Then, in order:

- Use the `build:precommit-runner` agent to run checks and fix failures.
- Use the `git:commit-handler` agent to create a `--fixup` commit targeting the appropriate commit.
- Replay the working branch onto the fixup commit: `git replay --onto HEAD HEAD^..<branch>`
- Autosquash non-interactively: `GIT_SEQUENCE_EDITOR=true git rebase --autosquash ${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}`
- If the rebase conflicts, use the `git:conflict-resolver` agent.
