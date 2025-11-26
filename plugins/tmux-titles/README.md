# tmux-titles Plugin

Automatically updates your tmux window title with visual indicators showing Claude Code's current status.

## Status Indicators

The plugin displays different icons in your tmux window title based on what Claude is doing:

- `✻` Working/Active (UserPromptSubmit, PostToolUse)
- `✓` Complete (Stop)
- `○` Session Start (SessionStart)
- `?` Question (Notification: permission_prompt/elicitation_dialog, PreToolUse: AskUserQuestion)
- `⌫` Cleanup (PreCompact)
- `$` Shell command (PreToolUse: Bash)
- `✎` File modification (PreToolUse: Edit/Write/MultiEdit)
- `…` File reading (PreToolUse: Read)

The window title format is: `[icon] [directory-name]`

## Requirements

- `jq` must be installed for JSON parsing
- tmux must be running
- safe to leave on when tmux is not running

## tmux Configuration

Add these settings to your `~/.config/tmux/tmux.conf`:

```tmux
# Enable automatic window renaming
set -g automatic-rename on

# Re-enable automatic rename after switching windows
set-hook -g after-select-window 'setw automatic-rename on'

# Choose window name format
# Option 1: Show directory name (matches plugin's [icon] [directory-name] format)
set -g automatic-rename-format '#{b:pane_current_path}'
# Option 2: Show process name (claude)
# set -g automatic-rename-format '#{pane_current_command}'
```

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
```
