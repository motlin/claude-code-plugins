---
name: restore
description: Rebuild herdr workspaces, tabs, and pane splits from a resume-after-reboot snapshot and resume the claude/codex agents that were running in them. Use after a reboot when asked to restore, rebuild, or bring back herdr sessions.
---

# Restore Herdr Workspaces

After a reboot, rebuild the session from the snapshot written by `/herdr-reboot:snapshot`: every
captured workspace with its label, every tab with its label, the panes inside each tab split at the
captured direction and ratio, then the resume command fired into each new pane.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this loaded `skills/restore/SKILL.md` file,
  including when the skill is installed outside the repository.

Preview the plan first:

```bash
python3 "<plugin-root>/scripts/restore.py" .llm/resume-after-reboot-state.json
```

The preview prints the tree it will build — workspaces, tabs, `split right 0.6` lines, and the
pane that each slot lands in. Show it to the user. Once they confirm, fire it:

```bash
python3 "<plugin-root>/scripts/restore.py" .llm/resume-after-reboot-state.json --go
```

Use `--limit N` to rebuild only the first N workspaces and `--skip 3,7` to leave individual slots
out entirely; a split left holding one pane collapses, and a tab left holding none is not created.
Agent launches are spaced 0.4s apart (`--delay`) so a couple dozen boots do not all land at once.

The state file is JSON, schema `resume-after-reboot/v2`, and is herdr-shaped. An older
`resume-after-reboot/v1` snapshot is flat, with no workspaces, tabs, or splits to rebuild, so
this restore rejects it rather than half-restoring it.

What the user needs to know before firing:

- `command` panes fire by default — bringing back dev servers like `just dev` is most of what a
  restore is for. Pass `--no-commands` to leave the dev servers (`restore_default: false`) alone
  when one outlived the reboot and still holds its port; read-only viewers (`git log`,
  `less FILE`, `htop`, `tig`) fire either way, re-running from the top without scroll position,
  search, or selection.
- herdr can bring the session back by itself, agents included, leaving only the command panes at
  a prompt. Check the preview for this: a workspace line reading `(adopt …)` and a tab line
  reading `(live …)` mean restore reuses what is already there. Each captured tab pairs with the
  live tab of the same label and split structure; its idle panes are fired into in place, and a
  pane already running its agent prints `LIVE` and is counted as already running. Only a captured
  tab with no live counterpart — renamed since the snapshot, or laid out differently — is created
  fresh.
- Nothing is ever typed into a pane that is not an idle shell. `herdr pane run` types into
  whatever the pane holds, so firing into a resumed agent would submit the resume command to it as
  a prompt. Every pane is fired only when confirmed to be sitting at a shell prompt with no live
  agent; anything else is skipped with a printed reason. Re-running the script is therefore safe.
- A live workspace with the same label and working directory is adopted rather than duplicated.
- Focus comes back last: each workspace's active tab, then the workspace that held focus. Focus
  inside a tab is restored as the tree is built, by creating the focused pane focused.
- Verify codex panes whose note says `herdr reported no session`. Those ids come from matching
  the working directory against rollout files on disk, so the pairing is a best guess. If a resumed
  session opens the wrong conversation, run `codex resume` in that pane and use the interactive
  picker.
- `claude-rc` panes are Remote Control servers, fired like any other agent pane. Their command
  reattaches with `--continue`, which errors out if nothing was recorded for that directory in
  roughly the last 4 hours — expect that on any reboot you did not come straight back from. The
  pane is left at a prompt; start a fresh server there by hand when you want one.
