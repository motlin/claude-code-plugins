# worktree-setup Plugin

Automatically copies gitignored files and configures direnv/mise when Claude Code's agent worktree isolation creates a new worktree.

## What It Does

When Claude Code spawns a Task agent with `isolation: "worktree"` or enters a worktree with `EnterWorktree`, the harness delegates worktree creation to this hook. This plugin hooks into the `WorktreeCreate` event to:

1. **Create the worktree** at `<cwd>/.claude/worktrees/<name>`, reusing a branch named `<name>` if one exists, otherwise branching from `origin/HEAD` (or from `HEAD` when the `worktree.baseRef` setting is `head`)
2. **Copy all gitignored files** from the source repo to the new worktree using `rsync`, preserving directory structure
3. **Run `direnv allow`** if `.envrc` exists in the worktree
4. **Run `mise trust`** if any mise config file exists in the worktree
5. **Print the worktree path** as the only line on stdout, which is how the harness learns where the worktree landed

This ensures the worktree has the same environment (build artifacts, local configs, tool versions) as the source repo.

## Requirements

- `git` - for listing gitignored files
- `jq` - for parsing hook input JSON
- `rsync` - for copying files with directory structure

### Optional

- `direnv` - for automatic `.envrc` approval in worktrees
- `mise` - for automatic mise config trust in worktrees

## Installation

```bash
claude plugin install worktree-setup@motlin-claude-code-plugins
```

## How It Works

The plugin registers a `WorktreeCreate` hook that runs `on-worktree-create.sh`. The script:

1. Reads the hook input JSON from stdin
2. Extracts the source directory (`cwd`) and the worktree `name`; the input carries no path field, so the worktree directory is derived as `<cwd>/.claude/worktrees/<name>`
3. Creates the worktree with `git worktree add` if the directory does not exist yet
4. Lists all gitignored files with `git ls-files --others --ignored --exclude-standard`
5. Copies them to the worktree with `rsync --archive`
6. Runs `direnv allow` and `mise trust` if applicable
7. Writes progress to stderr and the resolved worktree path to stdout

## Debugging

The hook input JSON is logged to `/tmp/worktree-create-hook-input.json` for schema discovery.
