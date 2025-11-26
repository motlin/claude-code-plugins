# iterm2-titles Plugin

Automatically updates your iTerm2 window title with visual indicators showing Claude Code's current status.

## Status Indicators

The plugin displays different icons in your iTerm2 window title based on what Claude is doing:

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
- `uv` must be installed for Python script execution
- iTerm2 terminal emulator

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install iterm2-titles@motlin-claude-code-plugins
```

## Shell Configuration

To automatically strip status icons when returning to the prompt (similar to how the tmux-titles plugin works), choose one or both approaches:

### Option 1: Shell precmd hook

Add this to your `~/.zshrc`:

```zsh
# Strip icons from terminal title before each prompt
precmd() {
  print -Pn "\e]0;%1~\a"
}
```

This strips icons before each shell prompt.

### Option 2: iTerm2 AutoLaunch script

Copy the monitor script to iTerm2's AutoLaunch directory:

```bash
cp ~/.claude/plugins/marketplaces/motlin-claude-code-plugins/plugins/iterm2-titles/scripts/monitor-tab-focus.py \
   ~/Library/Application\ Support/iTerm2/Scripts/AutoLaunch/
```

This uses iTerm2's Python API to strip icons when you switch tabs, independent of Claude Code running.
