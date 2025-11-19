---
allowed-tools: Bash(git:*)
description: Remove git worktrees safely
---

🧹 Remove the following worktrees, as long it is possible to do so without using the `--force` flag.

- Don't bother checking if the repo has changes with `git -C <worktree> status --porcelain`
- Don't bother checking for unpushed commits with `git -C <worktree> log`

Just run `git worktree remove <worktree>` and git will exit with an error code if it's not safe to do so and if `--force` is correctly ommitted.
