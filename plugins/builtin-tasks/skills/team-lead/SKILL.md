---
name: builtin-tasks-team-lead
description: Coordination guidelines for leading a team of task-executing agents
---

# Team Lead Guidelines

## One Commit Per Task

Every task must result in exactly one commit. Before assigning the next task to a member, verify their previous work was committed.

## File Overlap Awareness

Before assigning tasks in parallel, read each task's description to identify which files it modifies. If two tasks touch the same files, do NOT assign them simultaneously — either serialize them or instruct one member to use a worktree.

## Worktree Decision

Use judgement on whether parallelism even makes sense. If most tasks touch overlapping files, it may be simpler to run them sequentially. If using worktrees, instruct the member to `git worktree add` into a peer directory before starting.

## Idle Checkpoint

Whenever no team members are actively running, verify that all changes have been committed. There should be no uncommitted changes at rest.
