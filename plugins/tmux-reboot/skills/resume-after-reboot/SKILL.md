---
name: resume-after-reboot
description: 'Capture the running tmux/claude/codex session state before a reboot, and restore agents afterward. Use when the user says they need to reboot, restart, or update their machine and wants to keep their tmux agents; when they ask to snapshot, save, or record their sessions; or after a reboot when tmux-resurrect reopened windows but the claude/codex agents are gone and need resuming.'
---

# Resume After Reboot

tmux-resurrect restores tmux windows, panes, and working directories across a reboot, but the
`claude` and `codex` processes running inside them die and are not restarted. This skill snapshots
which agent was running in each window and the exact command to resume it, then drives the restore.

Two slash commands wrap the scripts: `/tmux-reboot:snapshot` and `/tmux-reboot:restore`.

## Before the reboot: capture

Run the snapshot script (or `/tmux-reboot:snapshot`) and save its output to the project's `.llm/`
(gitignored — the state holds session ids that are personal to this machine):

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot.py > .llm/resume-after-reboot-state.md
```

The script walks the process tree under every pane in the attached tmux session, identifies the
`claude` or `codex` agent, and resolves its resume id by matching the pane's cwd against the most
recently modified transcript on disk (`~/.claude/projects/<slug>/*.jsonl` for claude,
`~/.codex/sessions/.../rollout-*.jsonl` for codex, whose `session_meta` records the cwd).

Show the user the table and confirm it looks right, then they can reboot. Regenerate right before
rebooting so the ids are current — this is manual by default; only add a cron/launchd timer if the
user asks for automatic refresh.

## After the reboot: restore

Run `/tmux-reboot:restore`, which drives `restore.py`. It reads the state file, then sends each
window's resume command into the matching tmux window (`claude --resume <id>` / `codex resume <id>`;
`idle shell` rows are skipped). It is dry-run by default so you can preview the plan, and fires on
`--go`:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.md        # preview
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/restore.py .llm/resume-after-reboot-state.md --go    # fire
```

The window running the script is fired last so the restore is not interrupted mid-run.

## Resolution caveats

- **Multiple agents in one cwd** (e.g. two claude windows both in the same repo): ids are assigned
  newest-transcript-first. The _set_ of ids is correct, but which window gets which is best-effort —
  the conversations are usually interchangeable enough that the user can tell them apart on resume.
- **Stale mtime on a live codex session**: an idle agent's transcript has an old mtime but is still
  the right session; newest-per-cwd remains the best signal. If a row's `codex resume <id>` opens the
  wrong conversation, fall back to `codex resume` (interactive picker) in that window.
- **No transcript matched**: the command falls back to `claude --continue` (newest in cwd) or
  `codex resume --last`. Verify these after resuming.
- tmux runs a mirrored group session (`<name>-grouped-N`) alongside the real one; the script filters
  to the attached session so windows are not double-counted.
