# iterm2-titles Plugin

Automatically updates your iTerm2 window title with visual indicators showing Claude Code's current status.

## Status Indicators

The plugin displays different icons in your iTerm2 window title based on what Claude is doing:

- `✻` Working/Active (UserPromptSubmit, PostToolUse)
- `✓` Complete (Stop)
- `○` Session Start (SessionStart)
- `?` Question (Notification: permission_prompt)
- `⌫` Cleanup (PreCompact)
- `$` Shell command (PreToolUse: Bash)
- `✎` File modification (PreToolUse: Edit/Write/MultiEdit)
- `…` File reading (PreToolUse: Read)

The window title format is: `[icon] [directory-name]`

## Requirements

- `jq` must be installed for JSON parsing
- iTerm2 terminal emulator

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install iterm2-titles@motlin-claude-code-plugins
```
