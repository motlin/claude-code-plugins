---
name: restore
description: Rebuild herdr workspaces, tabs, and pane splits from a resume-after-reboot snapshot and resume the claude/codex agents that were running in them. Use after a reboot when asked to restore, rebuild, or bring back herdr sessions.
---

# Restore Herdr Workspaces

Rebuild the session from the snapshot written by `/herdr-reboot:snapshot`: each workspace and tab with its label, panes split at the captured direction and ratio, then the resume command fired into each pane.

Resolve `<plugin-root>`: `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, the plugin root containing this loaded `skills/restore/SKILL.md`, even when installed outside the repository.

Preview the plan and show it to the user:

```bash
python3 "<plugin-root>/scripts/restore.py" .llm/resume-after-reboot-state.json
```

The preview prints workspaces, tabs, `split right 0.6` lines, and the pane each slot lands in. Once the user confirms, fire it:

```bash
python3 "<plugin-root>/scripts/restore.py" .llm/resume-after-reboot-state.json --go
```

`--limit N` rebuilds only the first N workspaces; `--skip 3,7` leaves slots out (a split left with one pane collapses, and a tab left with none is not created). Agent launches are spaced 0.4s apart (`--delay`).

Only schema `resume-after-reboot/v2` is accepted. A flat `resume-after-reboot/v1` snapshot is rejected rather than half-restored.

Tell the user before firing:

- `command` panes fire by default, since bringing back dev servers like `just dev` is most of the point. `--no-commands` leaves dev servers (`restore_default: false`) alone when one outlived the reboot and holds its port. Read-only viewers (`git log`, `less FILE`, `htop`, `tig`) fire either way, from the top, without scroll position, search, or selection.
- herdr may already have brought the session back, agents included, leaving only command panes at a prompt. In the preview, `(adopt …)` on a workspace line and `(live …)` on a tab line mean restore reuses what exists. Each captured tab pairs with the live tab of the same label and split structure; its idle panes are fired into in place, and a pane already running its agent prints `LIVE`. Only a captured tab with no live counterpart (renamed or re-laid-out since the snapshot) is created fresh.
- Nothing is typed into a pane that is not an idle shell. `herdr pane run` types into whatever the pane holds, so firing into a resumed agent would submit the command as a prompt. Panes not confirmed at a shell prompt with no live agent are skipped with a printed reason, so re-running is safe.
- A live workspace with the same label and working directory is adopted, not duplicated.
- Focus comes back last: each workspace's active tab, then the focused workspace. In-tab focus is restored by creating the focused pane focused.
- Verify codex panes whose note says `herdr reported no session`; their ids are best guesses from matching the working directory against rollout files. If one opens the wrong conversation, run `codex resume` in that pane and use the picker.
- `claude-rc` panes are Remote Control servers, fired like any agent pane. `--continue` errors if nothing was recorded for the directory in roughly the last 4 hours, which is expected after any reboot you did not come straight back from. The pane is left at a prompt; start a fresh server by hand if wanted.
