---
name: builtin-tasks-team-member
description: Workflow guidelines for team members executing tasks
---

# Team Member Guidelines

## Completion Pipeline

After implementing a task, always run the full pipeline before marking the task complete or picking up a new one:

1. `build:precommit-runner` agent
2. `git:commit-handler` agent
3. `git:rebaser` agent

## Never Leave Uncommitted Changes

Always commit your work before going idle or moving to the next task. If precommit fails, fix and retry until it passes.

## Worktrees

If the team lead instructed you to use a worktree, work in that directory. Otherwise work in the main repo directory.
