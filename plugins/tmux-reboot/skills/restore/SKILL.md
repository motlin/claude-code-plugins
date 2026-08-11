---
name: restore
description: Restore claude/codex agents from a resume-after-reboot JSON state file after tmux-resurrect reopens their windows, whether the snapshot was taken by tmux-reboot or herdr-reboot. Use after a reboot when asked to restore, resume, or bring back tmux agents. For herdr instead of tmux, use the herdr-reboot plugin.
---

# Restore Tmux Agents

After a reboot, tmux-resurrect reopens the windows and working directories. Resume the agents that
were running in them from the JSON snapshot written by `/tmux-reboot:snapshot`.

Preview the plan first:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.json
```

Show the user the list of windows and resume commands. Once they confirm, fire them:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.json --go
```

The state file is JSON, schema `resume-after-reboot/v1`, and is interchangeable with the
`herdr-reboot` plugin — a snapshot taken under either plugin restores under the other. A file
written with any other `schema` value is rejected rather than guessed at. The header line of the
output echoes the `backend` and `captured` time so the user can see which plugin wrote the file and
how stale it is.

Rows are paired with live windows by `cwd`, not by position, because tmux-resurrect renumbers
windows. A row's `slot` is just a 1-based ordinal — pass `--skip SLOT` (repeatable) to leave one
row alone. The window running the script is fired last so the restore is not interrupted mid-run.
Each command is sent with a trailing Enter, so the user does not press return themselves — the
script both pastes and runs every resume line.

Rows with `"tool": "shell"` are idle panes with no command; they are skipped. Alongside
`claude`/`codex` agents, the snapshot may hold `command` rows — dev servers and watchers like
`just dev` (`restore_default: false`), and read-only viewers like `git log`, `less FILE`, or
`htop` (`restore_default: true`). This restore re-runs both the same way, unlike `herdr-reboot`,
which fires only the viewers unless asked. Point the dev-server rows out before firing, since
re-running one rebinds its port. Viewers re-run from the top: scroll position and search are not
restored.

Rows are only fired into windows sitting idle at a shell prompt with no live agent, so a repeated
run never types into a running program. Report the skipped rows to the user; "no live window with
this cwd" usually means tmux-resurrect has not finished restoring, or that pane's window is gone.

Verify rows whose `session_id` is `null` and whose command is `claude --continue` or
`codex resume --last`; those fallbacks mean the snapshot could not match an exact transcript. If a
resumed session opens the wrong conversation because one working directory held multiple agents or
an idle Codex transcript had a stale modification time, run `codex resume` or `claude --resume`
manually in that window and use the interactive picker.
