# tmux-titles

Hooks that store an agent activity symbol in the tmux window option `@claude_indicator` (`○` ready, `✻` working, `$` shell, `✎` edit, `…` read, `?` needs input, `⌫` compacting, `✓` stopped), plus `/rename <name>` to rename the agent's tmux window. Claude Code clears the option on session end. No-op outside tmux. Requires `jq`.

## Setup

The plugin does not edit `tmux.conf`. Render the option in a status format, for example:

```tmux
set -g window-status-format '#I:#F #{?@claude_indicator,#{@claude_indicator} ,}#W '
set -g window-status-current-format '#[bold]#I:#F #{?@claude_indicator,#{@claude_indicator} ,}#W#[default] '
```

Set `automatic-rename off` if `/rename` names should stick. Clear a stale symbol with `tmux set-option -wqu @claude_indicator`.
