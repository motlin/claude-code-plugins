# tmux-titles Plugin

`tmux-titles` places the current Claude Code or Codex activity beside a tmux window name. Hook
scripts store a one-character value in the window option `@claude_indicator`; your tmux status
format decides where and how that value appears.

The plugin targets tmux. For a terminal-owned title instead, use
[iterm2-titles](../iterm2-titles/README.md) or
[ghostty-titles](../ghostty-titles/README.md).

## Install

### Claude Code

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
```

### Codex

```bash
codex plugin marketplace add motlin/claude-code-plugins
codex plugin add tmux-titles@motlin-claude-code-plugins
```

Start a new agent session after installation so its hook manifest is loaded.

## Requirements

- Run the agent inside tmux with `TMUX` and `TMUX_PANE` available.
- Install `jq`; the prompt and tool hooks use it to read JSON input.
- Add `@claude_indicator` to the tmux status format. The plugin does not edit `tmux.conf`.

Every script exits successfully without changing anything when it is not running in tmux, so the
plugin can remain installed for sessions in other terminals.

## Configure tmux

Add the conditional indicator before `#W` in both window formats:

```tmux
set -g window-status-format "#I#F #{?@claude_indicator,#{@claude_indicator} ,}#W "
set -g window-status-current-format "#[bold]#I#F #{?@claude_indicator,#{@claude_indicator} ,}#W "
```

The window name can still come from tmux automatic renaming:

```tmux
set -g automatic-rename on
set -g automatic-rename-format '#{b:pane_current_path}'
```

Reload the configuration after editing it:

```bash
tmux source-file ~/.config/tmux/tmux.conf
```

Use the path where your tmux configuration is stored if it differs.

## Indicators

| Indicator | Meaning                 | Hook source                                                    |
| --------- | ----------------------- | -------------------------------------------------------------- |
| `○`       | Session started         | `SessionStart`                                                 |
| `✻`       | Working                 | `UserPromptSubmit`, `PostToolUse`, or other tool               |
| `$`       | Running a shell command | `PreToolUse` with `Bash`                                       |
| `✎`       | Creating or editing     | `PreToolUse` with `Create`, `Edit`, `Write`, or `MultiEdit`    |
| `…`       | Reading a file          | `PreToolUse` with `Read`                                       |
| `?`       | Waiting for an answer   | `AskUserQuestion`; Claude permission notifications also use it |
| `⌫`       | Compacting context      | `PreCompact`                                                   |
| `✓`       | Turn stopped            | `Stop`                                                         |

The common hook manifest used by Codex contains the events supported by both products. Claude Code
loads `claude-hooks.json`, which additionally sets `?` for permission or elicitation notifications
and clears the option on `SessionEnd`.

## Rename the Window

Submit a prompt beginning with `/rename `:

```text
/rename payments-api
```

The prompt hook targets the tmux session and window containing `TMUX_PANE`, then runs
`tmux rename-window` with the remaining text. This changes the window name itself; activity
indicators continue to live in the separate `@claude_indicator` option.

## How Targeting Works

At session startup, the plugin persists `TMUX_PANE` through the agent environment file when one is
available. Each update resolves that pane to a tmux session ID and window ID before changing the
window-scoped option. This avoids updating whichever window happens to be active when a hook
finishes.

The plugin also sets `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` in its settings so Claude Code's own
terminal-title updates do not compete with the tmux status display.

## Boundaries and Troubleshooting

- The indicator appears only when the status format references `@claude_indicator`.
- Indicators are window-scoped, so panes in the same window share one displayed state.
- The Codex-compatible hook set has no `SessionEnd` cleanup event; its last value can remain until
  another hook updates it or the option is unset.
- `/rename` requires a non-empty name and has no effect outside tmux.
- Hook commands use a 500 ms timeout. A missing tmux target becomes a no-op instead of interrupting
  the agent.

Inspect the current window value with:

```bash
tmux show-options -wv @claude_indicator
```

Clear it manually with:

```bash
tmux set-option -wqu @claude_indicator
```
