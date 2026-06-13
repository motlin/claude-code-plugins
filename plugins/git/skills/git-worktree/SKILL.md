---
name: git-worktree
description: Create a git worktree in a peer directory using the plugin worktree script.
---

# Git Worktree

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/git-worktree/SKILL.md` file.

Use the user-provided argument as a kebab-case branch name. If it is not already kebab-case, derive a short kebab-case name from it.

From the repository root, run:

```bash
<plugin-root>/scripts/worktree.sh <branch-name>
```

If the command fails, stop and summarize the error.

If it succeeds, report the created worktree path. Open a new terminal tab only if the user explicitly asks.
