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

The window title format is: `[icon] [name]` (or `[name] [icon]` with suffix positioning)

## Configuration

Configure the plugin via environment variables in your `settings.json`:

```json
{
  "env": {
    "TMUX_TITLES_MODE": "window",
    "TMUX_TITLES_POSITION": "suffix"
  }
}
```

### TMUX_TITLES_MODE

Controls how the window name is determined:
- `directory` (default) - Sets the window name to the current working directory name
- `window` - Uses the existing tmux window name

When using `window` mode, if your window is named "Bugfix" when you start Claude, it will display as "✻ Bugfix" while working, "✓ Bugfix" when complete, etc.

### TMUX_TITLES_POSITION

Controls where the status indicator appears:
- `prefix` (default) - Icon appears at the start: `✻ Bugfix`
- `suffix` - Icon appears at the end: `Bugfix ✻`

Using `suffix` is useful if you switch windows by typing the name (e.g., `<prefix> '` then window name), since the name stays at the beginning.

## Requirements

- `jq` must be installed for JSON parsing
- tmux must be running
- safe to leave on when tmux is not running

## tmux Configuration

### For `directory` mode (default)

Add these settings to your `~/.config/tmux/tmux.conf`:

```tmux
# Enable automatic window renaming
set -g automatic-rename on

# Re-enable automatic rename after switching windows
set-hook -g after-select-window 'setw automatic-rename on'

# Show directory name (matches plugin's format)
set -g automatic-rename-format '#{b:pane_current_path}'
```

### For `window` mode

When using `window` mode, you should disable automatic renaming so your custom window names persist:

```tmux
# Disable automatic window renaming to preserve custom names
set -g automatic-rename off
set -g allow-rename off
```

You can then name windows manually with `<prefix>,` or `tmux rename-window "my-window-name"`.

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
```
