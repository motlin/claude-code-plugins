---
description: Snapshot running tmux claude/codex agents so they can be resumed after a reboot
---

Capture the current tmux session state to a snapshot file, so `/tmux-reboot:restore` can bring the
agents back after a reboot restores the windows.

Run:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.py > .llm/resume-after-reboot-state.md
```

Then show the user the generated table and confirm it looks right before they reboot. The state file
holds session ids personal to this machine, so keep it in the gitignored `.llm/` directory.

Regenerate right before rebooting so the session ids are current.
