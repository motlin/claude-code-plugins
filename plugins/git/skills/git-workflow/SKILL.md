---
name: git-workflow
description: Git workflow best practices for commits, rebasing, conflict resolution, and branch management. Use when working with git operations, creating commits, resolving conflicts, or managing branches.
---

# Git Workflow Best Practices

This skill provides guidelines for git operations including commits, conflict resolution, and branch management.

## Commit Guidelines

### File Staging

📦 Stage files individually using `git add <file1> <file2> ...`
- NEVER use commands like `git add .`, `git add -A`, or `git commit -am` which stage all changes
- Use single quotes around file names containing `$` characters
  - Example: `git add 'app/routes/_protected.foo.$bar.tsx'`
- Only stage changes that you remember editing yourself

### Commit Message Style

Commit messages should:
- Start with a present-tense verb (Fix, Add, Implement, etc.)
- Be concise (60-120 characters)
- Be a single line
- End with a period
- Borrow language from the original prompt
- Avoid praise adjectives (comprehensive, robust, essential, best practices)
- Sound like the title of the issue we resolved
- Not include implementation details learned during implementation
- Echo exactly this: Running: `git commit --message "<message>"`
- 🚀 Run git commit without confirming again with the user

🐛 If fixing a compiler or linter error, create a `fixup` commit using `git commit --fixup <sha>`

### Pre-commit Hooks

When pre-commit hooks fail:
- Stage the files modified by the hooks individually
- Retry the commit
- Never use `git commit --no-verify`

## Splitting Changes into Multiple Commits

📝 When you have multiple logical changes, split them into separate commits:

1. Analyze local changes and propose splitting them into multiple logical commits
2. For each proposed commit, show the message and the list of files
3. Show all proposals at once
4. Wait for confirmation, then commit all

## Conflict Resolution

🔀 When resolving merge conflicts during a rebase:

1. Check `git status` to understand the state of the rebase and identify conflicted files
2. For each conflicted file:
   - Read the file to understand the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
   - Analyze what changes are in HEAD vs the incoming commit
   - Resolve conflicts by choosing the appropriate version or combining changes
   - Remove all conflict markers after resolution
3. After resolving all conflicts:
   - If project has a precommit check, run it and ensure no failures
   - Stage the resolved files with `git add`
   - Continue the rebase with `git rebase --continue`
4. If the rebase continues with more conflicts, repeat the process
5. Verify successful completion by checking git status and recent commit history

## Rebasing All Branches

🔄 Keep all branches in a repository up-to-date by rebasing them onto the upstream branch:

1. Run `just --global-justfile git-all` to attempt rebasing all branches
2. If the command fails with merge conflicts:
   - Resolve all conflicts in the affected branch
   - Run `just --global-justfile git-all` again
3. Continue this cycle until the command completes successfully without errors or conflicts

When communicating during multi-branch rebases:
- Clearly indicate which branch you're working on
- Summarize the conflicts found
- Report progress after each iteration
- Notify when the entire rebase process is complete

## Worktree Management

Git worktrees allow you to work on multiple branches simultaneously by checking out different branches in different directories.

### Creating Worktrees

Follow the repository's naming convention for worktree directories. Common patterns:
- Feature branches: `../repo-feature-name/`
- Bug fixes: `../repo-bugfix-name/`
- Version branches: `../repo-v2/`

### Cleaning Up Worktrees

Remove git worktrees safely when they're no longer needed:
- List existing worktrees with `git worktree list`
- Remove worktrees that are no longer in use
- Clean up both the working directory and git's internal tracking
