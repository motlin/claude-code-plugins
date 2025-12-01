---
name: git-workflow
description: Git workflow best practices for commits, rebasing, conflict resolution, and branch management. Use when working with git operations, creating commits, resolving conflicts, or managing branches.
---

# Git Workflow Best Practices

This skill provides guidelines for git operations including commits, conflict resolution, and branch management.

## Commit Guidelines

**ALWAYS** delegate to the `git:commit-handler` agent for all commit operations. Never run `git commit` directly.

## Conflict Resolution

**ALWAYS** delegate to the `git:conflict-resolver` agent to resolve any git merge or rebase conflicts.

## Rebasing

**ALWAYS** delegate to the `git:rebaser` agent to rebase the current branch on upstream.
