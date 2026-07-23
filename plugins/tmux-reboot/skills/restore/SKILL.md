---
name: restore
description: Restore claude/codex agents from a tmux-reboot snapshot after tmux-resurrect reopens their windows.
---

# Restore Tmux Agents

After a reboot, tmux-resurrect reopens the windows and working directories. Resume the agents that
were running in them from the snapshot written by `/tmux-reboot:snapshot`.

Preview the plan first:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.md
```

Show the user the list of windows and resume commands. Once they confirm, fire them:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.md --go
```

The window running the script is fired last so the restore is not interrupted mid-run. Each command
is sent with a trailing Enter, so the user does not press return themselves — the script both pastes
and runs every resume line.

Alongside `claude`/`codex` agents, the snapshot may hold `command` rows (dev servers and watchers
like `just dev`). These are re-run the same way. Point them out before firing, since re-running a dev
server rebinds its port.

Verify rows that use `claude --continue` or `codex resume --last`; these fallbacks mean the snapshot
could not match an exact transcript. If a resumed session opens the wrong conversation because one
working directory held multiple agents or an idle Codex transcript had a stale modification time,
run `codex resume` or `claude --resume` manually in that window and use the interactive picker.
