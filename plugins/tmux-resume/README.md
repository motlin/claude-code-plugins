# tmux-resume Plugin

Captures resumable Claude Code sessions from tmux before a reboot and relaunches them after `tm`
restores the tmux windows and working directories.

## Prerequisites

- Claude Code sessions must be running in tmux.
- `tm` must be configured to restore the tmux sessions, window and pane indexes, and working
  directories after reboot.
- `jq`, `tmux`, and the Claude Code CLI must be installed.
- Each Claude session must be exited interactively before capture. Capture does not exit sessions
  for you.

## Reboot Ritual

Follow these steps in order:

1. Before rebooting, interactively exit every Claude session with Ctrl-C twice, Ctrl-D, or `/exit`.
   Wait for each session to print its `Resume this session with: claude --resume <id>` footer.
2. Run `/capture` from Claude Code or run `plugins/tmux-resume/scripts/capture.sh` from a checkout.
   Capture writes `~/.claude/tmux-resume/last-capture.json`.
3. Reboot.
4. Run `tm` so it restores the tmux windows and their working directories.
5. Run `resume`. It replays `claude --resume <id>` into each matching restored pane.

A reboot sends SIGHUP but does **not** make Claude print the resume footer. This was verified, so
step 1 cannot be skipped. Capture also skips panes that still have a live Claude process.

## Resuming from the Post-Reboot Shell

No Claude session needs to be running before resume. From a shell inside the restored tmux session,
run the script directly:

```bash
plugins/tmux-resume/scripts/resume.sh
```

The `/resume` slash command is a convenience when one Claude session is already open; that session
can fan the relaunch out to the other restored panes. Resume skips a pane if it was not restored, its
working directory differs from the captured directory, or Claude is already running there.

## Limits

- The footer contains only `claude --resume <id>`. Extra launch flags are not recoverable. For
  example, Craig's `c` alias expands to `claude --chrome --verbose`, but capture cannot discover
  `--chrome --verbose` from the footer. An optional configurable suffix could append known flags such
  as `--chrome`; such a suffix is user-supplied configuration, not recovered session state.
- There are no hooks or live session registry.
- Capture never exits Claude sessions automatically; interactive exit is part of the ritual.
- There is no dependency on `@resurrect-capture-pane-contents`. The state needed for resume is stored
  on disk in `~/.claude/tmux-resume/last-capture.json`, so it survives reboot independently of saved
  pane contents.
