# worktree-setup Plugin

Automatically copies gitignored files and configures direnv/mise when Claude Code's agent worktree isolation creates a new worktree.

## What It Does

When Claude Code spawns a Task agent with `isolation: "worktree"`, the worktree only contains tracked files. This plugin hooks into the `WorktreeCreate` event to:

1. **Copy all gitignored files** from the source repo to the new worktree using `rsync`, preserving directory structure
2. **Run `direnv allow`** if `.envrc` exists in the worktree
3. **Run `mise trust`** if any mise config file exists in the worktree

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
2. Extracts the source directory (`cwd`) and worktree path
3. Lists all gitignored files with `git ls-files --others --ignored --exclude-standard`
4. Copies them to the worktree with `rsync --archive`
5. Runs `direnv allow` and `mise trust` if applicable

## Debugging

The hook input JSON is logged to `/tmp/worktree-create-hook-input.json` for schema discovery.
