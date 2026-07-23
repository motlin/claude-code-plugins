---
name: snapshot
description: Snapshot running tmux claude/codex agents immediately before a reboot so their sessions can be restored afterward.
---

# Snapshot Tmux Agents

Capture the current tmux session state to a snapshot file, so `/tmux-reboot:restore` can bring the
agents back after tmux-resurrect restores the windows, panes, and working directories. The running
`claude` and `codex` processes do not survive the reboot and must be resumed separately.

Run:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.py > .llm/resume-after-reboot-state.md
```

Then show the user the generated table and confirm it looks right before they reboot. The state file
holds session ids personal to this machine, so keep it in the gitignored `.llm/` directory.

The script walks the process tree under each pane in the attached tmux session and matches the
agent's working directory to recent transcripts on disk. Review these matching caveats with the
user when they affect the generated table:

- Multiple agents in one working directory are assigned newest-transcript-first. The set of session
  ids is correct, but the window-to-session assignment is best-effort.
- An idle Codex session can have a stale transcript modification time. If the assignment looks
  wrong, note that the user may need the interactive `codex resume` picker after reboot.
- When no transcript matches, the snapshot records `claude --continue` or `codex resume --last`.
  Point out these fallback rows so the user knows to verify them after restoration.
- The script ignores mirrored tmux group sessions and snapshots only the attached session.

Regenerate immediately before rebooting so the session ids are current. Keep refresh manual unless
the user asks to automate it with cron or launchd.
