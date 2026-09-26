---
name: snapshot
description: Snapshot running herdr workspaces, tabs, pane splits, and their claude/codex agents immediately before a reboot so they can be rebuilt afterward. Use when asked to snapshot, save, or capture herdr sessions before rebooting.
---

# Snapshot Herdr Workspaces

Capture the live herdr session so `/herdr-reboot:restore` can rebuild it after a reboot; nothing in it survives the reboot.

Resolve `<plugin-root>`: `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, the plugin root containing this loaded `skills/snapshot/SKILL.md`, even when installed outside the repository.

```bash
python3 "<plugin-root>/scripts/snapshot.py" --output .llm/resume-after-reboot-state.json
```

Show the user the tree and confirm it before the reboot. The state file holds machine-specific session ids, so keep it in the gitignored `.llm/` directory.

The file is JSON, schema `resume-after-reboot/v2`, mirroring the session: workspaces (label, number, active tab) hold tabs (label, number, zoom, focused pane), and each tab holds a `layout` tree of `split` nodes (`direction`, `ratio`) ending in `pane` leaves. It also records which workspace, tab, and pane held focus. `slot` numbers panes by workspace, then tab, then layout order.

Review these caveats with the user when they affect the panes:

- `claude` panes carry the session id herdr reports, so they are exact. Two ids are rejected because `claude --resume` would answer `No conversation found`: a **uuid v5** (claude mints v4, so a v5 is a derived placeholder) and an id whose transcript exists but is empty (the session never took a turn). Those panes fall back to `claude --continue` and say so in their note. A _missing_ transcript is not held against the id, since a pane in a git worktree derives a different project slug than the session was written under.
- `claude-rc` panes are Remote Control (`claude rc`, the server behind claude.ai/code and phone sessions). herdr reports the id of RC's startup placeholder session, which is never resumable and changes every launch, so these relaunch with `--continue`. That reattaches the session last recorded for the directory; past its ~4h window it errors and leaves the pane at a prompt, which beats a fresh server attached to nothing. Conversation state lives server-side, so relaunching by hand loses nothing.
- `codex` panes are exact only when herdr reported a session. herdr's codex integration reports nothing until the pane takes a turn, so an idle-since-launch codex pane falls back to matching its working directory against recent rollout files. Those notes say `herdr reported no session`; point them out, since the id is a best guess to verify after restore.
- `codex resume --last` means no rollout matched the working directory.
- `command` panes carry no session state; restore re-runs the command line. `restore_default` says whether restore's `--no-commands` still replays it:
    - `false` — long-lived dev servers and watchers (`just dev`, `npm run dev`, `vite`). Fired by default; `--no-commands` skips them when one survived and holds its port.
    - `true` — read-only viewers (`git log`, `git show`, `less FILE`, `man`, `htop`, `tig`, `lazygit`). Replayed either way.
- `git` panes are judged by subcommand, so `git push` and `git rebase` are never captured. An alias is judged by its expansion and restored as typed, so `git la` comes back as `git la`.
- A pager is captured only when it names a file. A bare `less` drains a pipe whose writer dies with the reboot, and re-running it would hang on stdin.
- A pane at an idle shell is judged by its **tab label**. A label of `rc` or `<name> rc` becomes a Remote Control relaunch named for the tab (or, for bare `rc`, its directory), patterned on a live RC pane's launch line when one exists, else plain `claude rc --name <name>`. Any other label is judged like a running process: its first word, alias-expanded in your interactive shell (so `j ta` counts when `j` is `just`), must be on the same allowlist, and the label is restored as typed. `op run` or `reboot` stays a shell. These notes say `inferred from tab label`; point them out.
- `shell` panes have nothing worth restoring; restore just recreates the pane.
- Editors and REPLs with in-memory state (`vim`, `psql`, `ssh`) are recorded as `shell` panes on purpose.
- `tig` and `lazygit` are captured as viewers, but both can stage, commit, and push from inside the TUI.

Regenerate immediately before rebooting so session ids are current. Keep refresh manual unless the user asks to automate it with cron or launchd. The file goes stale between reboots by design; don't chase drift or nag about refreshing.
