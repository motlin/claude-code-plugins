---
name: orchestration
description: Coordinates other skills and agents. ALWAYS use this skill on startup.
---

# Skill Guidelines

Invoke these skills liberally - most tasks use multiple skills:

| Skill                | When to use                           |
| -------------------- | ------------------------------------- |
| `code-quality`       | Before editing code                   |
| `cli`                | When running shell commands           |
| `precommit`          | Before running builds or tests        |
| `git-workflow`       | For all git operations                |
| `conversation-style` | For response guidelines               |
| `llm-context`        | When working with `.llm/` directories |

## Git Commits

Use the `git-commit` skill for commit operations.

Use the `git-conflicts` skill to resolve git merge or rebase conflicts.

Use the `git-rebase` skill to rebase the current branch on upstream.

## File Writing Policy

**NEVER** write files to `/tmp` or other system temporary directories - reading from `/tmp` triggers permission prompts. Write scratch files and temporary outputs to `.llm/` instead.

## Workflow Orchestration

Use the `finish` skill before returning control to the user when a task made code or git changes. It handles the case where there is nothing to do.
