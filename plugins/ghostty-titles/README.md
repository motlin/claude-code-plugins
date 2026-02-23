# ghostty-titles Plugin

Automatically updates your Ghostty tab title with visual indicators showing Claude Code's current status. Uses portable OSC 0 escape sequences (`\033]0;title\007`).

## Status Indicators

The plugin displays different icons in your Ghostty tab title based on what Claude is doing:

- `✻` Working/Active (UserPromptSubmit, PostToolUse)
- `✓` Complete (Stop)
- `○` Session Start (SessionStart)
- `?` Question (Notification: permission_prompt/elicitation_dialog, PreToolUse: AskUserQuestion)
- `⌫` Cleanup (PreCompact)
- `$` Shell command (PreToolUse: Bash)
- `✎` File modification (PreToolUse: Edit/Write/MultiEdit)
- `…` File reading (PreToolUse: Read)

The tab title format is: `[icon] [directory]`

## Requirements

- `jq` must be installed for JSON parsing
- Ghostty terminal (`TERM_PROGRAM=ghostty`)
- Safe to leave installed when not running in Ghostty; the scripts exit early as a no-op

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install ghostty-titles@motlin-claude-code-plugins
```
