# offline-claude-code-guide

Offline fallback for Claude Code documentation when the built-in `claude-code-guide` subagent fails due to network issues or proxy blocking.

## Usage

This plugin provides a skill that gives Claude access to locally cached Claude Code documentation. Use it when you need to ask Claude about Claude Code features and the network-based documentation lookup fails.

The skill reads from pre-downloaded documentation files in `docs/` directory.

## Commands

### `/refresh-claude-code-docs`

Update the offline documentation cache from https://code.claude.com/docs/en/

This command runs a script that:

1. Downloads the docs map from code.claude.com
2. Downloads all linked documentation files
3. Converts absolute links to relative links
4. Removes any invalid files (404 responses)

## Manual Refresh

You can also refresh the documentation manually:

```bash
plugins/offline-claude-code-guide/scripts/refresh-docs.sh
```
