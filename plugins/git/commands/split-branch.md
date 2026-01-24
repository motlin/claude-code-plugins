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

### Step 2: Generate Semantic Branch Names

For each commit, generate a descriptive branch name based on the commit content:

1. Analyze the commit message subject line
2. Create a short kebab-case name (3-5 words max) that captures what the commit does
3. Use conventional prefixes when appropriate: `add-`, `fix-`, `update-`, `remove-`, `refactor-`
4. Avoid generic names - be specific about what changed

Examples of good semantic names:

- "Add user authentication model" → `add-user-auth-model`
- "Fix null pointer in checkout" → `fix-checkout-null-pointer`
- "Update API rate limiting" → `update-api-rate-limits`

Show the user a numbered list with the proposed branch names:

```
Splitting branch `<current-branch>` into <N> branches:

1. <short-sha> <commit-subject> → <semantic-branch-name>
2. <short-sha> <commit-subject> → <semantic-branch-name>
...
```

Ask for confirmation before proceeding. Use the AskUserQuestion tool with options:

- "Proceed with these names" (recommended)
- "Regenerate names" (generate alternative names)
- "Use numbered naming" (fall back to <current-branch>-1, -2, etc.)
- "Cancel"

### Step 3: Create the Split Branches

For each commit (in order from oldest to newest):

1. Check if a branch with the target name already exists:

   ```
   git rev-parse --verify <semantic-branch-name> 2>/dev/null
   ```

   If it exists, compare the commit at that branch tip with the commit being cherry-picked:
   - If `git rev-parse <semantic-branch-name>` equals `<commit-sha>`, **skip** this branch (it's already done)
   - If different, append a numeric suffix to the branch name and continue

2. Create a new branch from the base branch:

   ```
   git branch <semantic-branch-name> <base-branch>
   ```

3. Cherry-pick the single commit onto that branch:

   ```
   git checkout <semantic-branch-name>
   git cherry-pick <commit-sha>
   ```

4. If cherry-pick fails due to conflicts:
   - Inform the user which commit/branch had conflicts
   - Leave the branch in the conflicted state
   - Continue with remaining branches
   - At the end, list all branches that need manual conflict resolution

5. Return to the original branch:
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
  ✓ add-user-model: abc1234 Add user model
  ✓ add-login-endpoint: def5678 Add login endpoint
  ⊘ add-session-handling: ghi9012 Add session handling (already exists, skipped)

2 branches created, 1 skipped.
```

## Important Notes

- NEVER delete or modify the original branch
- NEVER force push or destructively modify any existing branches
- If a branch name already exists, check if it contains the same commit (compare `git rev-parse <branch>` with the commit being cherry-picked). If identical, skip that branch and note it in the summary as "already exists". If different content, append a short numeric suffix (e.g., `add-user-model-2`)
- Always return to the original branch at the end
