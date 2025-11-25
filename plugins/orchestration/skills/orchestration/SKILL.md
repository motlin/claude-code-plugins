---
name: orchestration
description: Coordinates other skills and agents. ALWAYS use this skill on startup.
---

# Skill Guidelines

Invoke these skills liberally - most tasks use multiple skills:

| Skill                               | When to use                           |
| ----------------------------------- | ------------------------------------- |
| `@code:code-quality`                | Before editing code                   |
| `@code:testing`                     | When writing or reviewing tests       |
| `@code:cli`                         | When running shell commands           |
| `@build:precommit`                  | Before running builds or tests        |
| `@git:git-workflow`                 | For all git operations                |
| `@orchestration:conversation-style` | For response guidelines               |
| `@orchestration:llm-context`        | When working with `.llm/` directories |

## Workflow Orchestration

When a code change is ready, and we are about to return control to the user, do these things in order:

1. Verify the build passes using the `@build:precommit-runner` agent
2. Commit to git using the `@git:commit-handler` agent
3. Rebase on top of the upstream branch with the `@git:rebaser` agent
