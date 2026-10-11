---
name: move
description: Move herdr workspaces or single tabs from one herdr session to another, resuming their claude/codex agents in the target session. Use when asked to move, send, or transfer a workspace or tab to another herdr session, e.g. "move beta to later".
---

# Move Herdr Workspaces Between Sessions

Each herdr session is its own server, so panes cannot be handed across. The move snapshots the source session, closes the selection there, and rebuilds it in the target with the restore logic: claude panes come back via `claude --resume`, codex via `codex resume`, shells in the same directory, and command panes re-run.

Resolve `<plugin-root>`: `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, the plugin root containing this loaded `skills/move/SKILL.md`.

Each selector is a workspace label (`beta`) or `workspace/tab` for one tab (`alpha/dev`), which lands in the target as its own workspace named after the tab. `--from` defaults to the session this runs in.

Preview first and show the user what would be closed and rebuilt:

```bash
python3 "<plugin-root>/scripts/move.py" beta --to later
```

Once the user confirms, run it for real:

```bash
python3 "<plugin-root>/scripts/move.py" beta --to later --go
```

Tell the user before running `--go`:

- The target session must already be running. If it is not, the script says so and prints the `herdr session attach <name>` command; the user starts it in a terminal, then re-run. Never start it yourself.
- A selected pane whose agent is `working` refuses the whole move, since closing it interrupts the turn. Wait for it to finish. A `blocked` pane is moved with a warning: its pending prompt is dropped.
- The move refuses to include the pane it runs from. Run it from a pane outside the selection.
- The full source snapshot is backed up to `.llm/herdr-move-backup-<session>-<timestamp>.json` before anything closes. Restoring that file with `restore.py` (run with `HERDR_SESSION=<source>`) recovers from a failed move.
- `--no-commands` leaves dev-server command panes at a shell in the target, for when the source still holds their ports.
- After the move, a summary counts the moved panes by agent and status in the target. Agents still starting may show `unknown`.
