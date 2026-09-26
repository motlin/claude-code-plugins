# worktree-setup

`WorktreeCreate` hook for agent worktree isolation. Creates the worktree at `<cwd>/.claude/worktrees/<name>` (reusing branch `<name>` if it exists, else branching from `origin/HEAD`, or `HEAD` when `worktree.baseRef` is `head`), copies gitignored files with `rsync`, and runs `direnv allow` and `mise trust` when their config exists. Requires `git`, `jq`, and `rsync`. Hook input is logged to `/tmp/worktree-create-hook-input.json`.
