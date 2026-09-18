# git

Git workflow automation with smart commits, conflict resolution, rebase management, worktree creation, and worktree cleanup.

## Skills

Each skill is invoked as `/git:<name>`, and Claude also loads them on its own when a task matches.

### `/git:worktree`

Create a git worktree in a peer directory with project configuration files copied over.

### `/git:commit`

Commit local changes to git with careful file staging and single-line commit messages. When invoked directly, delegates to the `git:commit-handler` agent.

### `/git:commit-chunks`

Split local changes into multiple logical commits, proposing sensible groupings.

### `/git:conflicts`

Fix all merge conflicts and continue the git rebase.

### `/git:rebase-all`

Rebase all branches onto a configurable upstream branch.

### `/git:clean-worktrees`

Remove git worktrees safely without using `--force`.

### `/git:split-branch`

Split a branch with N commits into N branches with one commit each.

### `/git:reword-commits`

Rewrite every in-scope commit message to a single line with `git history reword`.

### `/git:wip`

Whole-repository cleanup: remove stale worktrees, rebase every branch, retest, and push.

### `/git:git-workflow`

Commit message format and git workflow rules shared by every commit and reword.

### `/git:git-rebase`

Rebase the current branch on the configured upstream using the plugin rebase script.

## Agents

- `git:commit-handler` - Commits local changes following the `git:commit` skill
- `git:conflict-resolver` - Resolves merge and rebase conflicts
- `git:rebaser` - Rebases local commits on top of upstream
