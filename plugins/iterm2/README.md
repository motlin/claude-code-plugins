# 🪟 iTerm2 Integration Plugin

This plugin automatically updates your iTerm2 window title with visual indicators showing Claude Code's current status.

## 📊 Status Indicators

The plugin displays different icons in your iTerm2 window title based on what Claude is doing:

- `✻` Working/Active (UserPromptSubmit, PostToolUse)
- `✓` Complete (Stop)
- `○` Session Start (SessionStart)
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
    "iterm2@motlin-claude-code-plugins": true
  }
}
```

2. The plugin will automatically update your iTerm2 window title when Claude performs actions.

## 🔧 How It Works

The plugin uses Claude Code's hook system to intercept various events:

- **SessionStart**: Shows `○` when a session starts
- **UserPromptSubmit**: Shows `✻` when you submit a prompt
- **Stop**: Shows `✓` when Claude finishes responding
- **Notification**: Shows `?` for permission requests
- **PreCompact**: Shows `⌫` during context cleanup
- **PreToolUse**: Shows tool-specific icons based on the tool being used
- **PostToolUse**: Returns to `✻` after tool execution

The window title format is: `[icon] [directory-name]`

## 📋 Requirements

- iTerm2 terminal emulator
- `jq` must be installed for JSON parsing
