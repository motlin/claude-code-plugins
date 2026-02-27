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

## How It Works

The plugin stores the current status indicator in a tmux window user option (`@claude_indicator`) rather than modifying the window name directly. This avoids conflicts with `automatic-rename` and per-window color formatting.

Your `window-status-format` and `window-status-current-format` in tmux.conf should include `#{?@claude_indicator,#{@claude_indicator} ,}` before `#W` to display the indicator.

## Requirements

- `jq` must be installed for JSON parsing
- tmux must be running
- safe to leave on when tmux is not running

## tmux Configuration

Add these settings to your `~/.config/tmux/tmux.conf`:

```tmux
# Enable automatic window renaming
set -g automatic-rename on
set -g automatic-rename-format '#{b:pane_current_path}'

# Include #{?@claude_indicator,#{@claude_indicator} ,} before #W in your format strings
# Example with just the indicator (no per-project colors):
set -g window-status-current-format "#[bold]#I#F #{?@claude_indicator,#{@claude_indicator} ,}#W "
set -g window-status-format "#I#F #{?@claude_indicator,#{@claude_indicator} ,}#W "
```

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
```
