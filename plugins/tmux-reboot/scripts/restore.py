#!/usr/bin/env python3
"""Restore claude/codex agents from a tmux-reboot snapshot.

Reads a state file produced by snapshot.py and sends each window's resume command into
the matching tmux window. Dry-run by default; pass --go to actually fire.

Usage:
    restore.py [state_file] [--go]
Defaults state_file to .llm/resume-after-reboot-state.md and to dry-run.
The window running this process is fired last so it isn't disrupted mid-restore.
"""
import subprocess, sys, os, re


def sh(args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def current_window(session):
    return sh(["tmux", "display-message", "-p", "#{window_index}"]).strip()


def parse(state_file):
    """Yield (win, cmd) for rows that carry a real resume command."""
    rows = []
    with open(state_file) as fh:
        for line in fh:
            if not line.startswith("| ") or line.startswith("| Win") or set(line.strip()) <= set("|-: "):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 4:
                continue
            win, name, tool, cmd = cells[0], cells[1], cells[2], cells[3]
            if tool in ("claude", "codex") and cmd.startswith("`") and cmd.endswith("`"):
                rows.append((win, cmd.strip("`")))
    return rows


def main():
    args = [a for a in sys.argv[1:] if a != "--go"]
    go = "--go" in sys.argv
    state = args[0] if args else ".llm/resume-after-reboot-state.md"
    if not os.path.exists(state):
        sys.exit(f"state file not found: {state}")

    session = sh(["tmux", "display-message", "-p", "#{session_name}"]).strip() or "main"
    here = current_window(session)
    rows = parse(state)
    # fire the current window last
    rows.sort(key=lambda r: r[0] == here)

    mode = "FIRING" if go else "DRY-RUN (pass --go to fire)"
    print(f"{mode}: {len(rows)} windows in session {session}\n")
    for win, cmd in rows:
        target = f"{session}:{win}"
        tag = " (current, last)" if win == here else ""
        print(f"  {target:<12} {cmd}{tag}")
        if go:
            sh(["tmux", "send-keys", "-t", target, cmd, "Enter"])
    if not go:
        print("\nNothing sent. Re-run with --go to resume these agents.")


if __name__ == "__main__":
    main()
