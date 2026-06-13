---
name: git-clean-worktrees
description: Remove git worktrees safely without force.
---

# Git Clean Worktrees

Remove the requested worktrees only if Git can do so without `--force`.

Do not pre-check status or unpushed commits. Run:

```bash
git worktree remove <worktree>
```

If Git refuses, report the error. Do not use `--force` unless the user explicitly asks for a destructive operation.
