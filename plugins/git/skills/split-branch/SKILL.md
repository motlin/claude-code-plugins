---
name: split-branch
description: Split a branch with N commits into N branches with 1 commit each. Use when the user asks to split a branch into single-commit branches.
---

# Split Branch

Split the current branch into one branch per commit. Never delete, modify, or force-push the original branch or any existing branch.

Use the `code:cli` skill.

## Base Branch and Commits

Use the base branch the user named. Otherwise, in order: the upstream tracking branch, then `main` or `master`, whichever exists. If none exists, ask.

```bash
git log --oneline --reverse <base-branch>..HEAD
```

With 0 commits there is nothing to split; with 1, splitting isn't useful. Say so and stop.

## Branch Names

For each commit, derive a short kebab-case name (3-5 words) from its subject, using prefixes like `add-`, `fix-`, `update-`, `remove-`, `refactor-` where they fit. For example, "Fix null pointer in checkout" becomes `fix-checkout-null-pointer`.

Show the proposal:

```text
Splitting branch `<current-branch>` into <N> branches:

1. <short-sha> <commit-subject> → <semantic-branch-name>
2. <short-sha> <commit-subject> → <semantic-branch-name>
...
```

Ask via AskUserQuestion:

- "Proceed with these names" (recommended)
- "Regenerate names"
- "Use numbered naming" (`<current-branch>-1`, `-2`, etc.)
- "Cancel"

## Create the Branches

Work from oldest commit to newest. For each commit, check whether the target branch exists:

```bash
git rev-parse --verify <semantic-branch-name> 2>/dev/null
```

If it exists and its tip equals `<commit-sha>`, skip it. If it exists with a different tip, append a numeric suffix (e.g., `add-user-model-2`). Then:

```bash
git branch <semantic-branch-name> <base-branch>
git switch <semantic-branch-name>
git cherry-pick <commit-sha>
```

If a cherry-pick conflicts, tell the user which commit and branch, leave the branch conflicted, and continue with the rest. When done, return to the original branch with `git switch <original-branch>`.

## Summary

List the preserved original branch, each new branch with its commit, skipped branches, and branches that need manual conflict resolution:

```text
Successfully split `feature-auth` into 3 branches:

Original branch (preserved):
  feature-auth (3 commits)

New single-commit branches:
  ✓ add-user-model: abc1234 Add user model
  ✓ add-login-endpoint: def5678 Add login endpoint
  ⊘ add-session-handling: ghi9012 Add session handling (already exists, skipped)

2 branches created, 1 skipped.
```
