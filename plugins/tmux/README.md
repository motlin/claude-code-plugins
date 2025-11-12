# 🪟 tmux Integration Plugin

This plugin automatically updates your tmux window title with visual indicators showing Claude Code's current status.

## 📊 Status Indicators

The plugin displays different icons in your tmux window title based on what Claude is doing:

- `✻` Working/Active (UserPromptSubmit, PostToolUse)
- `✓` Complete (Stop)
- `⏸` Idle (Notification: idle_prompt)
- `?` Question (Notification: permission_prompt)
- `⌫` Cleanup (PreCompact)
- `$` Shell command (PreToolUse: Bash)
- `✎` File modification (PreToolUse: Edit/Write/MultiEdit)
- `…` File reading (PreToolUse: Read)

## 🚀 Installation

1. Enable the plugin in your `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "tmux@motlin-claude-code-plugins": true
  }
}
```

2. The plugin will automatically update your tmux window title when Claude performs actions.

## 🔧 How It Works

The plugin uses Claude Code's hook system to intercept various events:

- **UserPromptSubmit**: Shows `✻` when you submit a prompt
- **Stop**: Shows `✓` when Claude finishes responding
- **Notification**: Shows `⏸` for idle or `?` for permission requests
- **PreCompact**: Shows `⌫` during context cleanup
- **PreToolUse**: Shows tool-specific icons based on the tool being used
- **PostToolUse**: Returns to `✻` after tool execution

The window title format is: `[icon] [original-window-name]`

## 📋 Requirements

- tmux must be running (the plugin checks for the `TMUX` environment variable)
- `jq` must be installed for JSON parsing
