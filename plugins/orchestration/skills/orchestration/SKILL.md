---
name: orchestration
description: Coordinates other skills and agents. ALWAYS use this skill on startup.
---

# Skill Guidelines

Most tasks use several of these skills:

| Skill                              | When to use                           |
| ---------------------------------- | ------------------------------------- |
| `code:code-quality`                | Before editing code                   |
| `code:cli`                         | When running shell commands           |
| `build:precommit`                  | After code changes                    |
| `git:git-workflow`                 | For all git operations                |
| `orchestration:conversation-style` | For response guidelines               |
| `orchestration:llm-context`        | When working with `.llm/` directories |
| `recap:recap`                      | Before ending a turn                  |

## Git

Use the `git:commit` skill to commit, `git:conflicts` to resolve merge or rebase conflicts, and `git:git-rebase` to rebase the current branch on upstream.

## Temporary files

Write scratch files and temporary output to `.llm/`, not `/tmp` or other system temp directories; reading from `/tmp` triggers permission prompts.

## Finishing

Before returning control after a task that made code or git changes, use the `orchestration:finish` skill.
