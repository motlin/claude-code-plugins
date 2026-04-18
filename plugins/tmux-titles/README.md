# tmux-titles Plugin

Updates your tmux window title with a single-character indicator showing what Claude Code is doing right now. At a glance across multiple panes, you can see which sessions are working, which are done, and which are waiting for you.

## Status Indicators

| Indicator   | Meaning                 | Hook Event                                                   |
| ----------- | ----------------------- | ------------------------------------------------------------ |
| `○`         | Session started         | SessionStart                                                 |
| `✻`         | Working                 | UserPromptSubmit, PostToolUse                                |
| `$`         | Running a shell command | PreToolUse: Bash                                             |
| `✎`         | Editing a file          | PreToolUse: Edit/Write/MultiEdit                             |
| `…`         | Reading a file          | PreToolUse: Read                                             |
| `?`         | Waiting for input       | Notification: permission_prompt, PreToolUse: AskUserQuestion |
| `⌫`         | Compacting context      | PreCompact                                                   |
| `✓`         | Done                    | Stop                                                         |
| _(cleared)_ | Session ended           | SessionEnd                                                   |

The indicator updates in real time as Claude Code moves through its workflow. A typical sequence: `○` → `✻` → `…` → `✎` → `$` → `✻` → `✓`.

## How It Works

The plugin uses a tmux **window user option** (`@claude_indicator`) rather than modifying the window name directly. This is important — setting the window name would conflict with tmux's `automatic-rename` feature and make it impossible to use per-window color formatting.

The flow:

- Each Claude Code hook event triggers a shell script
- The script writes the indicator to `@claude_indicator` using `tmux set-option -wq`
- Your `window-status-format` reads the option and displays it before the window name
- When the session ends, `clear-tmux-title.sh` removes the option entirely

The scripts are safe to run when tmux is not available — they check for `$TMUX` and `$TMUX_PANE` and exit silently if either is missing.

### Pane Persistence

On `SessionStart`, the plugin writes `export TMUX_PANE='...'` to Claude Code's `$CLAUDE_ENV_FILE`. This preserves the pane identity across subprocesses and agents that might otherwise lose the `$TMUX_PANE` variable.

## tmux Configuration

Add the `#{?@claude_indicator,...}` conditional to your window status format strings. This displays the indicator when it's set and nothing when it isn't:

```tmux
# Enable automatic window renaming (shows the directory name)
set -g automatic-rename on
set -g automatic-rename-format '#{b:pane_current_path}'

# Add the Claude indicator before #W in both format strings
set -g window-status-current-format "#[bold]#I#F #{?@claude_indicator,#{@claude_indicator} ,}#W "
set -g window-status-format "#I#F #{?@claude_indicator,#{@claude_indicator} ,}#W "
```

The `#{?@claude_indicator,#{@claude_indicator} ,}` expression means: if `@claude_indicator` is set, show its value followed by a space; otherwise show nothing.

## Rename Window

Type `/rename my-project` in Claude Code to rename the current tmux window. The `UserPromptSubmit` hook matches prompts starting with `/rename ` and calls `tmux rename-window` with the name you provide.

## Requirements

- `jq` for JSON parsing (hooks receive JSON on stdin)
- tmux (safe to leave installed when tmux is not running)

## Also Available

- **[iterm2-titles](../iterm2-titles/README.md)** — Same indicators for iTerm2
- **[ghostty-titles](../ghostty-titles/README.md)** — Same indicators for Ghostty

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
```
