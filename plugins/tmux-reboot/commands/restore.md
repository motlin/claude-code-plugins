---
description: Resume the claude/codex agents recorded in a tmux-reboot snapshot
---

After a reboot, tmux-resurrect reopens the windows and cwds. This resumes the agents that were
running in them, from the snapshot written by `/tmux-reboot:snapshot`.

Preview the plan first (dry-run):

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.md
```

Show the user the list of windows and resume commands. Once they confirm, fire them:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.md --go
```

The window you are running in is fired last so the restore is not interrupted mid-run.

If a resumed session opens the wrong conversation (possible when one cwd held multiple live agents,
or a codex session had a stale transcript mtime), run `codex resume` or `claude --resume` manually in
that window using the picker. See the resume-after-reboot skill for the full resolution caveats.
