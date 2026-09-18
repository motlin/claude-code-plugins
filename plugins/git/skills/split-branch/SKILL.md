---
name: split-branch
description: Split a branch with N commits into N branches with 1 commit each. Use when the user asks to split a branch into single-commit branches.
---

# Split Branch

Split the current branch into multiple branches, each containing a single commit.

ALWAYS use the `code:cli` skill.

## Inspect Context

Run:

```bash
git branch --show-current
git branch --list
git for-each-ref --format='%(refname:short) -> %(upstream:short)' refs/heads/
```

## Base Branch

If the user named a base branch, use it. Otherwise detect the base branch, in this order: the upstream tracking branch if there is one, then `main` or `master` (whichever exists). If neither exists, ask the user to specify one.

## Identify Commits to Split

Run:

```bash
git log --oneline --reverse <base-branch>..HEAD
```

This shows all commits on the current branch that aren't on the base branch.

If there are 0 commits, inform the user there's nothing to split and stop.
If there is 1 commit, inform the user there's only one commit so splitting isn't useful, and stop.

## Generate Semantic Branch Names

For each commit, generate a descriptive branch name based on the commit content:

- Analyze the commit message subject line
- Create a short kebab-case name (3-5 words max) that captures what the commit does
- Use conventional prefixes when appropriate: `add-`, `fix-`, `update-`, `remove-`, `refactor-`
- Avoid generic names; be specific about what changed

Examples of good semantic names:

- "Add user authentication model" → `add-user-auth-model`
- "Fix null pointer in checkout" → `fix-checkout-null-pointer`
- "Update API rate limiting" → `update-api-rate-limits`

Show the user a numbered list with the proposed branch names:

```text
Splitting branch `<current-branch>` into <N> branches:

1. <short-sha> <commit-subject> → <semantic-branch-name>
2. <short-sha> <commit-subject> → <semantic-branch-name>
...
```

Ask for confirmation before proceeding. Use the AskUserQuestion tool with options:

- "Proceed with these names" (recommended)
- "Regenerate names" (generate alternative names)
- "Use numbered naming" (fall back to `<current-branch>-1`, `-2`, etc.)
- "Cancel"

## Create the Split Branches

Work through the commits in order from oldest to newest. For each commit:

Check if a branch with the target name already exists:

```bash
git rev-parse --verify <semantic-branch-name> 2>/dev/null
```

If it exists, compare the commit at that branch tip with the commit being cherry-picked:

- If `git rev-parse <semantic-branch-name>` equals `<commit-sha>`, **skip** this branch (it's already done)
- If different, append a numeric suffix to the branch name (e.g., `add-user-model-2`) and continue

Create a new branch from the base branch:

```bash
git branch <semantic-branch-name> <base-branch>
```

Cherry-pick the single commit onto that branch:

```bash
git switch <semantic-branch-name>
git cherry-pick <commit-sha>
```

If the cherry-pick fails due to conflicts:

- Inform the user which commit/branch had conflicts
- Leave the branch in the conflicted state
- Continue with the remaining branches
- At the end, list all branches that need manual conflict resolution

After all commits, return to the original branch:

```bash
git switch <original-branch>
```

## Summary

Present a summary showing:

- The original branch (unchanged): `<current-branch>`
- All newly created branches with their single commit
- Any branches that need conflict resolution

Example output:

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

## Important Notes

- NEVER delete or modify the original branch
- NEVER force push or destructively modify any existing branches
