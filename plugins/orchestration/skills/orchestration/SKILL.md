---
name: orchestration
description: Coordinates other skills and agents. ALWAYS use this skill on startup.
---

# Skill Guidelines

Invoke these skills liberally - most tasks use multiple skills:

| Skill                               | When to use                           |
| ----------------------------------- | ------------------------------------- |
| `@code:code-quality`                | Before editing code                   |
| `@code:cli`                         | When running shell commands           |
| `@build:precommit`                  | Before running builds or tests        |
| `@git:git-workflow`                 | For all git operations                |
| `@orchestration:conversation-style` | For response guidelines               |
| `@orchestration:llm-context`        | When working with `.llm/` directories |

## Git Commits

**ALWAYS** delegate to the `@git:commit-handler` agent for all commit operations. Never run `git commit` directly.

**ALWAYS** delegate to the `@git:conflict-resolver` agent to resolve any git merge or rebase conflicts.

**ALWAYS** delegate to the `@git:rebaser` agent to rebase the current branch on upstream.

## File Writing Policy

**NEVER** write files to `/tmp` or other system temporary directories - reading from `/tmp` triggers permission prompts. Write scratch files and temporary outputs to `.llm/` instead.

## Workflow Orchestration

Always run `/orchestration:finish` before returning control to the user. It handles the case where there's nothing to do.
