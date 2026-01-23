---
argument-hint: [base-branch]
description: Split a branch with N commits into N branches with 1 commit each
---

Split the current branch into multiple branches, each containing a single commit.

ALWAYS use the `code:cli` skill.

## Context

- Current branch: !`git branch --show-current`
- All local branches: !`git branch --list`
- Remote tracking info: !`git for-each-ref --format='%(refname:short) -> %(upstream:short)' refs/heads/`

## Arguments

The user passed in: `$ARGUMENTS`

If the user specified a base branch, use that. Otherwise, detect the base branch:

1. Check if there's an upstream tracking branch
2. Fall back to `main` or `master` (whichever exists)
3. If neither exists, ask the user to specify

## Task

### Step 1: Identify Commits to Split

Run: `git log --oneline --reverse <base-branch>..HEAD`

This shows all commits on the current branch that aren't on the base branch.

If there are 0 commits, inform the user there's nothing to split and stop.
If there is 1 commit, inform the user there's only one commit so splitting isn't useful, and stop.

### Step 2: Present the Plan

Show the user a numbered list of the commits that will become individual branches:

```
Splitting branch `<current-branch>` into <N> branches:

1. <short-sha> <commit-subject> -> <current-branch>-1
2. <short-sha> <commit-subject> -> <current-branch>-2
...
```

Ask for confirmation before proceeding. Use the AskUserQuestion tool with options:

- "Proceed with split" (recommended)
- "Use different naming" (let user specify a prefix)
- "Cancel"

### Step 3: Create the Split Branches

For each commit (in order from oldest to newest):

1. Create a new branch from the base branch:

   ```
   git branch <current-branch>-<N> <base-branch>
   ```

2. Cherry-pick the single commit onto that branch:

   ```
   git checkout <current-branch>-<N>
   git cherry-pick <commit-sha>
   ```

3. If cherry-pick fails due to conflicts:
   - Inform the user which commit/branch had conflicts
   - Leave the branch in the conflicted state
   - Continue with remaining branches
   - At the end, list all branches that need manual conflict resolution

4. Return to the original branch:
   ```
   git checkout <original-branch>
   ```

### Step 4: Summary

Present a summary showing:

- The original branch (unchanged): `<current-branch>`
- All newly created branches with their single commit
- Any branches that need conflict resolution

Example output:

```
Successfully split `feature-auth` into 3 branches:

Original branch (preserved):
  feature-auth (3 commits)

New single-commit branches:
  feature-auth-1: abc1234 Add user model
  feature-auth-2: def5678 Add login endpoint
  feature-auth-3: ghi9012 Add session handling

All branches created successfully.
```

## Important Notes

- NEVER delete or modify the original branch
- NEVER force push or destructively modify any existing branches
- If a branch name already exists, append a timestamp suffix (e.g., `feature-auth-1-20240115`)
- Always return to the original branch at the end
