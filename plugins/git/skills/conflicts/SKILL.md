---
name: conflicts
description: Resolve git merge or rebase conflicts and continue the operation. Use when a rebase, merge, or cherry-pick stops on conflicted files.
---

# Conflicts

🔀 Fix all merge conflicts and continue the git rebase.

Use the `code:cli` skill.

Run `git status` to understand the merge or rebase state and identify conflicted files.

For each conflicted file:

- Read the file and inspect the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
- Understand the HEAD side and incoming side.
- Resolve by choosing the correct version or combining changes.
- Remove all conflict markers.

✅ After resolving all conflicts:

```bash
git add <resolved-files>
git rebase --continue
```

If the rebase continues with more conflicts, repeat the process inline, or run the `git:conflict-resolver` subagent again when the conflicts were delegated to it in the first place.

✔️ Verify successful completion with `git status` and recent commit history.
