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

## Git Commits

**ALWAYS** delegate to the `@git:commit-handler` agent for all commit operations. Never run `git commit` directly.

**ALWAYS** delegate to the `@git:conflict-resolver` agent to resolve any git merge or rebase conflicts.

**ALWAYS** delegate to the `@git:rebaser` agent to rebase the current branch on upstream.

## File Writing Policy

**NEVER** write files to `/tmp` or other system temporary directories - reading from `/tmp` triggers permission prompts. Write scratch files and temporary outputs to `.llm/` instead.

## Workflow Orchestration

When a code change is ready, and we are about to return control to the user, do these things in order:

1. Verify the build passes using the `@build:precommit-runner` agent
2. Commit to git using the `@git:commit-handler` agent
3. Rebase on top of the upstream branch with the `@git:rebaser` agent

## Plugin Health Check

Run the master doctor script to verify all plugins are properly configured:

```bash
${CLAUDE_PLUGIN_ROOT}/../orchestration/scripts/doctor-all.sh
```

This runs `doctor.sh` from each plugin, checking for:

- Required binaries (just, git, gh, python3, tmux, etc.)
- Required files and scripts
- Proper file permissions
