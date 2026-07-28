# tmux-titles

See what an agent is doing without switching to its tmux window. `tmux-titles`
records a single activity symbol in the window option `@claude_indicator`.
You choose where that option appears by adding it to a tmux status format.

The plugin also provides `/rename <name>` for assigning a descriptive name to
the window that owns the agent pane. Renaming the window and reporting activity
are independent: the name stays in `#W`, while the activity symbol changes as
hooks run.

Use [iterm2-titles](../iterm2-titles/README.md) or
[ghostty-titles](../ghostty-titles/README.md) when the terminal application's
title bar is the desired destination.

## Requirements

- Claude Code or Codex must start inside tmux.
- The session must expose both `TMUX` and `TMUX_PANE`.
- `tmux` must be available on `PATH`.
- `jq` must be installed for the prompt and tool hooks.
- Your tmux status format must render `@claude_indicator`.

Hooks return without an error when the tmux environment or target pane is
missing. Installing the plugin therefore does not interfere with agent sessions
started outside tmux, but those sessions do not show an indicator or support
window renaming.

## Installation

For Claude Code, register this repository as a marketplace and install the
plugin:

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
```

For Codex:

```bash
codex plugin marketplace add motlin/claude-code-plugins
codex plugin add tmux-titles@motlin-claude-code-plugins
```

Open a new agent session after installation. Hooks are loaded when the session
starts.

The plugin setting `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` prevents Claude Code
from separately changing the terminal title. It does not disable tmux window
names or tmux status formats.

## Add the indicator to tmux

The plugin only sets a user option; it does not modify `tmux.conf`. A compact
window list can put the activity immediately before the window name:

```tmux
set -g window-status-format '#I:#F #{?@claude_indicator,#{@claude_indicator} ,}#W '
set -g window-status-current-format '#[bold]#I:#F #{?@claude_indicator,#{@claude_indicator} ,}#W#[default] '
```

`#{?@claude_indicator,...}` hides the extra space when no value exists. `#W`
continues to display the tmux window name.

For a status bar that keeps the window list unchanged, render the active
window's value in `status-right` instead:

```tmux
set -g status-right '#{?@claude_indicator,Agent #{@claude_indicator} | ,}%Y-%m-%d %H:%M'
```

Choose one placement or adapt the format fragments to an existing theme. Reload
the configuration with:

```bash
tmux source-file "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf
```

If tmux reads another file on your machine, pass that path instead.

## Activity lifecycle

The stored value changes when an agent hook runs:

| Symbol | Observable state               | Event                                          |
| ------ | ------------------------------ | ---------------------------------------------- |
| `○`    | Session is ready               | Startup                                        |
| `✻`    | Agent is working               | Prompt submitted or tool finished              |
| `$`    | Shell command is starting      | `Bash` tool                                    |
| `✎`    | File change is starting        | `Create`, `Edit`, `Write`, or `MultiEdit` tool |
| `…`    | File read is starting          | `Read` tool                                    |
| `?`    | User input is needed           | `AskUserQuestion` tool                         |
| `⌫`    | Context compaction is starting | Pre-compact                                    |
| `✓`    | Agent turn has stopped         | Stop                                           |

Every other tool maps to `✻`. After any tool completes, the post-tool hook also
restores `✻`, so a tool-specific symbol describes the tool currently starting
rather than a permanent mode.

Claude Code has two additional lifecycle behaviors:

- Permission prompts and elicitation dialogs set `?`.
- Session end removes `@claude_indicator` from the window.

The common hook manifest does not define those notification and session-end
events. When that manifest is in use, the final symbol remains until another
hook changes it or the option is cleared.

All hooks have a 500 ms timeout. The scripts resolve `TMUX_PANE` to a session ID
and window ID before writing the option, so a delayed hook still targets the
window where the agent started instead of whichever window is currently
selected. At startup, the pane ID is appended to `CLAUDE_ENV_FILE` when that
environment file is available, preserving the target for later hooks.

Because `@claude_indicator` is a window option, panes in the same tmux window
share one indicator. If multiple agents run in one window, their latest hook
wins.

## Rename a window

Submit a prompt whose complete prefix is `/rename `:

```text
/rename api-tests
```

The remainder becomes the tmux window name. An empty name, a prompt without
that prefix, or a prompt submitted outside tmux changes nothing. The script
passes the name directly to `tmux rename-window`, including embedded spaces.

Automatic renaming can overwrite a manual name later. Disable it when
`/rename` should remain authoritative:

```tmux
set -g automatic-rename off
```

Alternatively, keep automatic renaming enabled and let tmux derive names from
the pane path:

```tmux
set -g automatic-rename on
set -g automatic-rename-format '#{b:pane_current_path}'
```

## Cleanup

Claude Code removes the window option through its `SessionEnd` hook. To clear a
stale value yourself, target the current window:

```bash
tmux set-option -wqu @claude_indicator
```

That command removes the option; it does not rename the window. A later agent
hook can create the option again.

## Troubleshooting

### No symbol appears

Confirm that the option has a value:

```bash
tmux show-options -wv @claude_indicator
```

If a symbol is printed, add `#{@claude_indicator}` or the conditional form from
the examples to the status format. If the command reports an unknown option,
start a new agent session inside tmux and submit a prompt.

### Tool-specific symbols never appear

Verify that `jq` is on the same `PATH` available to the agent:

```bash
command -v jq
```

The tool and rename scripts use `jq` to read hook input. The other lifecycle
scripts do not parse JSON.

### The wrong window changes

Check that the agent inherited a pane ID:

```bash
printf '%s\n' "${TMUX_PANE:-missing}"
```

The value must name the pane where the agent runs. Hook scripts deliberately do
nothing when `TMUX_PANE` is empty or cannot be resolved by tmux.

### A symbol remains after the agent exits

Session-end cleanup is defined only in the Claude Code hook manifest. Use the
manual cleanup command above when the active integration does not emit that
event or when a session ends before its hook runs.
