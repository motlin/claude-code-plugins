# pushover Plugin

Send Pushover notifications to your phone when Claude Code needs your attention.

## When Notifications Are Sent

The plugin sends notifications when Claude is blocked waiting for you:

- **Permission prompts** - When Claude needs permission to run a tool
- **Questions** - When Claude uses the AskUserQuestion tool to ask for input

These are the same events that trigger the `?` indicator in the tmux-titles and iterm2-titles plugins.

## Requirements

- The `woof` command in your PATH (sends messages via Pushover)

## Installation

```bash
claude plugin install pushover@motlin-claude-code-plugins
```

## How It Works

Uses `SILENT=true woof '<message>'` to send notifications without the voice announcement.
