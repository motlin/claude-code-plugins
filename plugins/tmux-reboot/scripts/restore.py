#!/usr/bin/env python3
"""Restore claude/codex agents from a tmux-reboot snapshot.

Reads a state file produced by snapshot.py and sends each row's resume command into the
matching tmux window. Dry-run by default; pass --go to actually fire.

Windows are matched by cwd, not by index: tmux-resurrect renumbers windows across a
reboot, so a positional lookup fires resume commands into the wrong windows. Each row is
paired with a live window whose current path equals the recorded cwd. A row is only fired
into a window sitting idle at a shell prompt with no live agent, so a mistargeted or
repeated run never types into a running program.

Usage:
    restore.py [state_file] [--go]
Defaults state_file to .llm/resume-after-reboot-state.md and to dry-run.
The window running this process is fired last so it isn't disrupted mid-restore.
"""
import subprocess, sys, os

HOME = os.path.expanduser("~")
SHELLS = {"zsh", "bash", "sh", "fish", "dash", "ksh", "tcsh"}


def sh(args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def basename(cmd):
    return cmd.split("/")[-1].lstrip("-") if cmd else ""


def parse(state_file):
    """Return a dict per row that carries a real resume command."""
    rows = []
    with open(state_file) as fh:
        for line in fh:
            if not line.startswith("| ") or line.startswith("| Win") or set(line.strip()) <= set("|-: "):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 5:
                continue
            win, name, tool, cmd, cwd = cells[0], cells[1], cells[2], cells[3], cells[4]
            if tool in ("claude", "codex", "command") and cmd.startswith("`") and cmd.endswith("`"):
                rows.append({"win": win, "name": name, "tool": tool,
                             "cmd": cmd.strip("`"), "cwd": os.path.expanduser(cwd.replace("~", HOME))})
    return rows


def live_windows(session):
    """window_index -> {cwd, pid, cur} for the first pane of each window in the session."""
    out = {}
    fmt = "#{session_name}|#{window_index}|#{pane_current_path}|#{pane_pid}|#{pane_current_command}"
    for line in sh(["tmux", "list-panes", "-a", "-F", fmt]).splitlines():
        sess, win, cwd, pid, cur = line.split("|")
        if sess == session or session is None:
            out.setdefault(win, {"cwd": cwd, "pid": pid, "cur": cur})
    return out


def proc_tree():
    kids = {}
    cmd = {}
    for line in sh(["/bin/ps", "-axo", "pid=,ppid=,command="]).splitlines():
        p = line.strip().split(None, 2)
        if len(p) < 3:
            continue
        pid, ppid, c = int(p[0]), int(p[1]), p[2]
        kids.setdefault(ppid, []).append(pid)
        cmd[pid] = c
    return kids, cmd


def has_agent(pid, kids, cmd):
    """True if a claude/codex descendant is already running under pid."""
    for k in kids.get(pid, []):
        c = cmd.get(k, "")
        base = basename(c.split()[0]) if c else ""
        if base == "claude" or (base in ("codex", "node") and "codex" in c):
            return True
        if has_agent(k, kids, cmd):
            return True
    return False


def idle_shell(pid, cur):
    """A pane is idle when its foreground command is just its own login shell."""
    shell = basename(sh(["/bin/ps", "-p", pid, "-o", "comm="]).strip())
    return basename(cur) == shell and shell in SHELLS


def main():
    go = "--go" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--go"]
    state = args[0] if args else ".llm/resume-after-reboot-state.md"
    if not os.path.exists(state):
        sys.exit(f"state file not found: {state}")

    session = sh(["tmux", "display-message", "-p", "#{session_name}"]).strip() or "main"
    here = sh(["tmux", "display-message", "-p", "#{window_index}"]).strip()
    rows = parse(state)
    wins = live_windows(session)
    kids, cmd = proc_tree()

    # Prefer the recorded window when its cwd still matches; else any unclaimed
    # window with the same cwd. Lowest index first for a stable pairing.
    claimed = set()
    plan, skips = [], []
    for r in rows:
        candidates = [r["win"]] if wins.get(r["win"], {}).get("cwd") == r["cwd"] else []
        candidates += sorted((w for w, d in wins.items() if d["cwd"] == r["cwd"]), key=int)
        win = next((w for w in candidates if w not in claimed), None)
        if win is None:
            skips.append((r, "no live window with this cwd"))
            continue
        d = wins[win]
        if has_agent(int(d["pid"]), kids, cmd):
            skips.append((r, f"window {win} already has a live agent"))
            continue
        if not idle_shell(d["pid"], d["cur"]):
            skips.append((r, f"window {win} is running {basename(d['cur'])}, not idle"))
            continue
        claimed.add(win)
        plan.append((win, r))

    plan.sort(key=lambda p: p[0] == here)  # fire the current window last
    mode = "FIRING" if go else "DRY-RUN (pass --go to fire)"
    print(f"{mode}: {len(plan)} matched, {len(skips)} skipped, session {session}\n")
    for win, r in plan:
        moved = "" if win == r["win"] else f"  (recorded win {r['win']})"
        here_tag = "  (current, last)" if win == here else ""
        print(f"  {session}:{win:<4} {r['cmd']:<58} @{r['cwd'].replace(HOME, '~')}{moved}{here_tag}")
        if go:
            sh(["tmux", "send-keys", "-t", f"{session}:{win}", r["cmd"], "Enter"])
    for r, why in skips:
        print(f"  SKIP  {r['name']:<20} {r['cmd']:<58} @{r['cwd'].replace(HOME, '~')} -- {why}")
    if not go:
        print("\nNothing sent. Re-run with --go to resume these agents.")


if __name__ == "__main__":
    main()
