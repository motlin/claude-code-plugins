---
name: git-conflicts
description: Resolve git merge or rebase conflicts and continue the operation.
---

# Git Conflicts

Use the `code:cli` skill.

Run `git status` to understand the merge or rebase state and identify conflicted files.

For each conflicted file:

- Read the file and inspect conflict markers.
- Understand the HEAD side and incoming side.
- Resolve by choosing the correct version or combining changes.
- Remove all conflict markers.

After resolving all conflicts:

```bash
git add <resolved-files>
git rebase --continue
```

If more conflicts appear, repeat the process. Verify completion with `git status` and recent commit history.
