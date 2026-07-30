---
name: snapshot
description: Snapshot running herdr workspaces, tabs, and their claude/codex agents immediately before a reboot so they can be rebuilt afterward. Use when asked to snapshot, save, or capture herdr sessions before rebooting. For tmux instead of herdr, use the tmux-reboot plugin.
---

# Snapshot Herdr Workspaces

Capture the live herdr session so `/herdr-reboot:restore` can rebuild it after a reboot. Nothing
survives the reboot — not the workspaces, not the tabs, not the agents inside them.

Run:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.py --output .llm/resume-after-reboot-state.json
```

Then show the user the rows and confirm they look right before the reboot. The state file holds
session ids personal to this machine, so keep it in the gitignored `.llm/` directory.

The state file is JSON, schema `resume-after-reboot/v1`, and is interchangeable with the
`tmux-reboot` plugin: either plugin's restore reads the other's snapshot.

Each pane becomes one row, numbered by workspace order then tab order so `slot` follows the visual
layout. Review these caveats with the user when they affect the rows:

- `claude` rows carry the session id herdr itself reports, so they need no guessing and are exact.
- `codex` rows are only exact when herdr reported a session. herdr's codex integration reports
  nothing until that pane takes a turn, so a codex pane that has been idle since launch falls back
  to matching its working directory against recent rollout files on disk. Those rows say
  `herdr reported no session` in their note — point them out, since the id is a best guess and
  should be verified after restoration.
- `codex resume --last` means no rollout matched the working directory at all.
- `command` rows are long-lived foreground programs (dev servers and watchers like `just dev`,
  `npm run dev`, `vite`). They carry no session state, so restoring one just re-runs the command
  line. Restore skips them by default because dev servers frequently survive the reboot and still
  hold their ports.
- `shell` rows are panes with nothing worth restoring; the restore just recreates the tab.
- Editors and REPLs with in-memory state (`vim`, `psql`, `ssh`) are intentionally recorded as
  `shell` rows rather than re-run.

Regenerate immediately before rebooting so the session ids are current. Keep refresh manual unless
the user asks to automate it with cron or launchd.
