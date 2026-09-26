---
name: clean-worktrees
description: Remove git worktrees safely without force. Use when the user asks to remove, clean up, or delete git worktrees.
---

# Clean Worktrees

Remove exactly the worktrees the user named. If they named none, ask which ones.

Don't pre-check for local changes or unpushed commits (`git status`, `git log`). Run the removal and let Git refuse when it is unsafe:

```bash
git worktree remove <worktree>
```

Without `--force`, Git exits with an error when the worktree has modified or untracked files. If Git refuses, report the error. Never add `--force`.
