---
name: restore
description: Rebuild herdr workspaces, tabs, and pane splits from a resume-after-reboot snapshot and resume the claude/codex agents that were running in them. Use after a reboot when asked to restore, rebuild, or bring back herdr sessions. For tmux instead of herdr, use the tmux-reboot plugin.
---

# Restore Herdr Workspaces

After a reboot, rebuild the session from the snapshot written by `/herdr-reboot:snapshot`: every
captured workspace with its label, every tab with its label, the panes inside each tab split at the
captured direction and ratio, then the resume command fired into each new pane.

Preview the plan first:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.json
```

The preview prints the tree it will build — workspaces, tabs, `split right 0.6` lines, and the
pane that each slot lands in. Show it to the user. Once they confirm, fire it:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.json --go
```

Use `--limit N` to rebuild only the first N workspaces and `--skip 3,7` to leave individual slots
out entirely; a split left holding one pane collapses, and a tab left holding none is not created.
Agent launches are spaced 0.4s apart (`--delay`) so a couple dozen boots do not all land at once.

The state file is JSON, schema `resume-after-reboot/v2`, and is herdr-shaped. A `tmux-reboot`
snapshot (`resume-after-reboot/v1`) is flat, with no workspaces, tabs, or splits to rebuild, so
this restore rejects it rather than half-restoring it.

What the user needs to know before firing:

- `command` panes split on their `restore_default` field. Dev servers (`restore_default: false`)
  are skipped: they often survive the reboot that killed the agents, and re-running one just fails
  with `EADDRINUSE` against the server still holding the port. Their pane is still created, so the
  user can start them by hand. Pass `--commands` to fire them anyway, only after confirming the
  old processes are gone.
- Read-only viewers (`restore_default: true` — `git log`, `less FILE`, `htop`, `tig`) fire without
  `--commands`. Nothing of theirs survives a reboot, so the `EADDRINUSE` reasoning does not apply.
  They re-run from the top: scroll position, search, and selection are not restored.
- Nothing is ever typed into a pane that is not an idle shell. `herdr pane run` types into
  whatever the pane holds, so firing into a resumed agent would submit the resume command to it as
  a prompt. Every pane is fired only when confirmed to be sitting at a shell prompt with no live
  agent; anything else is skipped with a printed reason. Re-running the script is therefore safe.
- A live workspace with the same label and working directory is adopted rather than duplicated.
  Its captured tabs land there as brand new tabs, never reusing its live panes.
- Focus comes back last: each workspace's active tab, then the workspace that held focus. Focus
  inside a tab is restored as the tree is built, by creating the focused pane focused.
- Verify codex panes whose note says `herdr reported no session`. Those ids come from matching
  the working directory against rollout files on disk, so the pairing is a best guess. If a resumed
  session opens the wrong conversation, run `codex resume` in that pane and use the interactive
  picker.
- `claude-rc` panes are Remote Control servers, fired like any other agent pane. Their command
  reattaches with `--continue`, which errors out if nothing was recorded for that directory in
  roughly the last 4 hours — expect that on any reboot you did not come straight back from. The
  pane is left at a prompt; start a fresh server there by hand when you want one.
