---
name: conflicts
description: Resolve git merge or rebase conflicts and continue the operation. Use when a rebase, merge, or cherry-pick stops on conflicted files.
---

# Conflicts

Use the `code:cli` skill.

Run `git status` to see the operation in progress and the conflicted files. Resolve each file by keeping the correct side or combining both, and remove every conflict marker, then stage them with `git add <resolved-files>`.

Continue the operation that is actually in progress. `git rev-parse --git-path <name>` resolves each marker correctly inside worktrees:

| Marker present                     | Operation   | Continue with                |
| ---------------------------------- | ----------- | ---------------------------- |
| `rebase-merge/` or `rebase-apply/` | rebase      | `git rebase --continue`      |
| `MERGE_HEAD`                       | merge       | `git merge --continue`       |
| `CHERRY_PICK_HEAD`                 | cherry-pick | `git cherry-pick --continue` |
| `REVERT_HEAD`                      | revert      | `git revert --continue`      |

Check the rebase markers first; they take precedence over any other marker a stopped rebase leaves behind. When `--continue` would open an editor, prefix it with `GIT_EDITOR=true` to keep the default message.

If the operation stops on more conflicts, repeat.

Finish by checking `git status` and recent commit history to confirm the operation completed.
