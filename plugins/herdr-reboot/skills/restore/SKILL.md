---
name: restore
description: Rebuild herdr workspaces and tabs from a resume-after-reboot snapshot and resume the claude/codex agents that were running in them. Use after a reboot when asked to restore, rebuild, or bring back herdr sessions. For tmux instead of herdr, use the tmux-reboot plugin.
---

# Restore Herdr Workspaces

After a reboot, rebuild the workspaces from the snapshot written by `/herdr-reboot:snapshot`: one
workspace per distinct working directory, one tab per row, then the resume command fired into each
new pane.

Preview the plan first:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.json
```

Show the user the workspace and tab plan. Once they confirm, fire it:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.json --go
```

Use `--limit N` to rebuild only the first N workspaces and `--skip 3,7` to leave individual slots
out entirely. Agent launches are spaced 0.4s apart (`--delay`) so a couple dozen boots do not all
land at once.

The state file is JSON, schema `resume-after-reboot/v1`, and is interchangeable with the
`tmux-reboot` plugin: this restore reads a snapshot captured by either backend.

What the user needs to know before firing:

- `command` rows are skipped by default. Dev servers often survive the reboot that killed the
  agents, and re-running one just fails with `EADDRINUSE` against the server still holding the
  port. Their tab is still created, so the user can start them by hand. Pass `--commands` to fire
  them anyway, only after confirming the old processes are gone.
- Nothing is ever typed into a pane that is not an idle shell. `herdr pane run` types into
  whatever the pane holds, so firing into a resumed agent would submit the resume command to it as
  a prompt. Every row is fired only into a pane confirmed to be sitting at a shell prompt with no
  live agent; anything else is skipped with a printed reason. Re-running the script is therefore
  safe.
- Existing workspaces are adopted rather than duplicated. When a workspace already has a row's
  working directory, the rows land there as brand new tabs rather than reusing its live panes.
- Verify codex rows whose note says `herdr reported no session`. Those ids come from matching
  the working directory against rollout files on disk, so the pairing is a best guess. If a resumed
  session opens the wrong conversation, run `codex resume` in that tab and use the interactive
  picker.
