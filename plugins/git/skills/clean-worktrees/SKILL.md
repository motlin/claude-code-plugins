---
name: clean-worktrees
description: Remove git worktrees safely without force. Use when the user asks to remove, clean up, or delete git worktrees.
---

# Clean Worktrees

🧹 Remove the worktrees the user named, as long as Git can do so without the `--force` flag.

If the user passed worktree paths, remove exactly those. Otherwise ask which worktrees to remove.

Do not pre-check the worktree first:

- Don't check for local changes with `git -C <worktree> status --porcelain`
- Don't check for unpushed commits with `git -C <worktree> log`

Just run the removal and let Git refuse when it is not safe:

```bash
git worktree remove <worktree>
```

Git exits with an error when the worktree has modified or untracked files, as long as `--force` is omitted. If Git refuses, report the error. Never add `--force`.
