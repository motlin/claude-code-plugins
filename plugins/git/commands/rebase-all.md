---
allowed-tools: Task, Bash(just:*)
description: Rebase all branches onto a configurable upstream branch
---

🔄 Keep all branches in a repository up-to-date by rebasing them onto a configurable upstream branch.

Initial Rebase Attempt: Run `just --global-justfile git-all` to attempt rebasing all branches.
- If the command fails with merge conflicts, use the `git-rebase-conflict-resolver` agent to resolve all conflicts in the affected branch
- After resolving conflicts run `just --global-justfile git-all` again.
- Continue this cycle until the command completes successfully without errors or conflicts.

When communicating:
- Clearly indicate which branch you're working on.
- Summarize the conflicts found.
- Report progress after each iteration.
- Notify when the entire rebase process is complete.

Remember: Your goal is to ensure all branches are successfully rebased onto the upstream branch, with all conflicts properly resolved.
