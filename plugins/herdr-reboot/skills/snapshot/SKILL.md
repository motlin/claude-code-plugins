---
name: snapshot
description: Snapshot running herdr workspaces, tabs, pane splits, and their claude/codex agents immediately before a reboot so they can be rebuilt afterward. Use when asked to snapshot, save, or capture herdr sessions before rebooting. For tmux instead of herdr, use the tmux-reboot plugin.
---

# Snapshot Herdr Workspaces

Capture the live herdr session so `/herdr-reboot:restore` can rebuild it after a reboot. Nothing
survives the reboot — not the workspaces, not the tabs, not the agents inside them.

Run:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.py --output .llm/resume-after-reboot-state.json
```

Then show the user the tree and confirm it looks right before the reboot. The state file holds
session ids personal to this machine, so keep it in the gitignored `.llm/` directory.

The state file is JSON, schema `resume-after-reboot/v2`, and mirrors the session's own shape:
workspaces (with label, number, and active tab) hold tabs (with label, number, zoom, and focused
pane), and each tab holds a `layout` tree of `split` nodes — `direction` and `ratio` — bottoming
out in `pane` leaves. The document also records which workspace, tab, and pane held focus. It is
herdr-shaped, so the `tmux-reboot` plugin, which speaks the flat `resume-after-reboot/v1`, neither
reads nor writes it.

Each pane is one leaf, and `slot` numbers them by workspace order, then tab order, then layout
order, so a slot follows the visual layout. Review these caveats with the user when they affect
the panes:

- `claude` panes carry the session id herdr itself reports, so they need no guessing and are exact.
- `codex` panes are only exact when herdr reported a session. herdr's codex integration reports
  nothing until that pane takes a turn, so a codex pane that has been idle since launch falls back
  to matching its working directory against recent rollout files on disk. Those panes say
  `herdr reported no session` in their note — point them out, since the id is a best guess and
  should be verified after restoration.
- `codex resume --last` means no rollout matched the working directory at all.
- `command` panes carry no session state, so restoring one just re-runs the command line. Their
  `restore_default` field says whether restore replays it unasked:
    - `false` — long-lived dev servers and watchers (`just dev`, `npm run dev`, `vite`). Skipped by
      default, because these frequently survive the reboot and still hold their ports.
    - `true` — read-only viewers (`git log`, `git show`, `less FILE`, `man`, `htop`, `tig`,
      `lazygit`). None of these outlives the reboot, so restore replays them by default.
- `git` panes are judged by subcommand, not by program, so `git push` and `git rebase` are never
  captured. An alias is judged by what it expands to and restored as the alias you typed, so
  `git la` comes back as `git la`.
- A pager is captured only when it names a file. A bare `less` is draining a pipe whose writer
  dies with the reboot, and re-running it would hang the pane on stdin.
- `shell` panes are panes with nothing worth restoring; the restore just recreates the pane.
- Editors and REPLs with in-memory state (`vim`, `psql`, `ssh`) are intentionally recorded as
  `shell` panes rather than re-run.
- `tig` and `lazygit` are captured as viewers, but both can stage, commit, and push from inside
  the TUI — a restored one is only as safe as what you then type at it.

Regenerate immediately before rebooting so the session ids are current. Keep refresh manual unless
the user asks to automate it with cron or launchd.
