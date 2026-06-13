---
name: git-split-branch
description: Split the current branch into multiple branches with one commit each.
---

# Git Split Branch

Use the `code:cli` skill.

Determine the base branch from the user argument, upstream tracking branch, `main`, or `master`. Ask if no base is clear.

List commits:

```bash
git log --oneline --reverse <base-branch>..HEAD
```

If there are fewer than two commits, explain that there is nothing useful to split.

For each commit, propose a short kebab-case branch name based on the commit subject and content. Show all names and ask for confirmation.

For each commit:

- If the target branch exists and already points at that commit, skip it.
- If the target branch exists with different content, append a numeric suffix.
- Create the branch from the base branch.
- Switch to it and cherry-pick the commit.
- If conflicts occur, report the branch and continue with remaining branches.
- Return to the original branch.

Never delete or modify the original branch. Never force push.
