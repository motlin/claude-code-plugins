---
name: snapshot
description: Snapshot running tmux claude/codex agents to a resume-after-reboot JSON state file immediately before a reboot, so their sessions can be restored afterward. Use when asked to snapshot, save, or capture tmux sessions before rebooting. For herdr instead of tmux, use the herdr-reboot plugin.
---

# Snapshot Tmux Agents

Capture the current tmux session state to a snapshot file, so `/tmux-reboot:restore` can bring the
agents back after tmux-resurrect restores the windows, panes, and working directories. The running
`claude` and `codex` processes do not survive the reboot and must be resumed separately. Panes
running a long-lived foreground command (dev servers and watchers like `just dev`, `npm run dev`,
`vite`, `cargo watch`) or a read-only viewer (`git log`, `git show`, `less FILE`, `man`, `htop`,
`tig`, `lazygit`) are also captured as `command` rows — these carry no session state, so restoring
one just re-runs the command line (best-effort). Their `restore_default` field separates the two:
`false` for dev servers, `true` for viewers.

Run:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.py --output .llm/resume-after-reboot-state.json
```

Stdout works too, for redirection: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.py > FILE`.

Then show the user the captured rows and confirm they look right before they reboot. The state file
holds session ids personal to this machine, so keep it in the gitignored `.llm/` directory.

## The state file

JSON, schema `resume-after-reboot/v1`. One row per window:

```json
{
	"schema": "resume-after-reboot/v1",
	"captured": "2026-07-29T20:22:47-04:00",
	"backend": "tmux",
	"session": "main",
	"rows": [
		{
			"slot": 1,
			"name": "webapp",
			"tool": "claude",
			"command": "claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607",
			"cwd": "~/projects/webapp",
			"session_id": "3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607",
			"note": "session mtime 2026-07-29 20:17"
		}
	]
}
```

- `tool` is `claude`, `codex`, `command`, or `shell`. `shell` rows are idle panes: `command` and
  `session_id` are `null` and nothing is restored into them.
- `slot` is a 1-based ordinal for ordering and display, not a tmux window index — restore pairs
  rows by `cwd`, because tmux-resurrect renumbers windows across a reboot.
- `session_id` is broken out of `command` so nothing has to re-parse the command string. It is
  `null` for `command`/`shell` rows and for the `claude --continue` / `codex resume --last`
  fallbacks.
- `note` records how the pairing was made, so a weak one is visible.

The format is tmux-shaped: a flat row list, since tmux-resurrect brings the windows and panes back
on its own. The `herdr-reboot` plugin writes a nested `resume-after-reboot/v2` document instead —
workspaces, tabs, and splits included — so the two are not interchangeable.

## Matching caveats

The script walks the process tree under each pane in the attached tmux session and matches the
agent's working directory to recent transcripts on disk. Review these with the user when they
affect the captured rows:

- Multiple agents in one working directory are assigned newest-transcript-first. The set of session
  ids is correct, but the window-to-session assignment is best-effort — that is what `note` records.
- An idle Codex session can have a stale transcript modification time. If the assignment looks
  wrong, note that the user may need the interactive `codex resume` picker after reboot.
- When no transcript matches, the snapshot records `claude --continue` or `codex resume --last` with
  a `null` `session_id`. Point out these fallback rows so the user knows to verify them after
  restoration.
- The script ignores mirrored tmux group sessions and snapshots only the attached session.
- `command` rows re-run their command line, not a saved session. Editors, REPLs, and shells with
  in-memory state (`vim`, `psql`, `ssh`) are intentionally not captured — only allowlisted
  long-running commands and read-only viewers are. Point these rows out as best-effort restores.
- `git` rows are judged by subcommand, not by program, so `git push` and `git rebase` are never
  captured. An alias is judged by what it expands to and restored as the alias you typed, so
  `git la` comes back as `git la`.
- A pager is captured only when it names a file. A bare `less` is draining a pipe whose writer
  dies with the reboot, and re-running it would hang the pane on stdin.
- `tig` and `lazygit` are captured as viewers, but both can stage, commit, and push from inside
  the TUI — a restored one is only as safe as what you then type at it.

Regenerate immediately before rebooting so the session ids are current. Keep refresh manual unless
the user asks to automate it with cron or launchd.
