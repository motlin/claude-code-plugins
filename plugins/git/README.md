# git

Git workflow automation with smart commits, conflict resolution, rebase management, worktree creation, and worktree cleanup.

## Commands

### `/worktree`

Create a git worktree in a peer directory with project configuration files copied over.

### `/commit`

Commit local changes to git with intelligent file staging and commit message generation.

### `/commit-chunks`

Split local changes into multiple logical commits, proposing sensible groupings.

### `/conflicts`

Fix all merge conflicts and continue the git rebase automatically.

### `/rebase-all`

Rebase all branches onto a configurable upstream branch.

### `/clean-worktrees`

Remove git worktrees safely without using `--force`.

## Shared Files

- `shared/git-commit-instructions.md` - Common commit workflow and message conventions
