---
name: conflicts
description: Resolve git merge or rebase conflicts and continue the operation. Use when a rebase, merge, or cherry-pick stops on conflicted files.
---

# Conflicts

Use the `code:cli` skill.

Run `git status` to see the operation in progress and the conflicted files. Resolve each file by keeping the correct side or combining both, and remove every conflict marker. Then:

```bash
git add <resolved-files>
git rebase --continue
```

If the rebase stops on more conflicts, repeat. When the conflicts were delegated to the `git:conflict-resolver` agent, run that agent again instead.

Finish by checking `git status` and recent commit history to confirm the operation completed.
