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

## Prefer Modern Git Commands

Use newer git commands instead of their legacy equivalents whenever possible:

- `git switch` instead of `git checkout` for switching branches
- `git switch -c` instead of `git checkout -b` for creating branches
- `git restore` instead of `git checkout --` for restoring files
- `git restore --staged` instead of `git reset HEAD` for unstaging files
- `git history reword` instead of interactive rebase or amending for editing commit messages
- `git history split` instead of interactive rebase for splitting commits
