#!/usr/bin/env python3
"""Restore claude/codex agents from a resume-after-reboot snapshot.

Reads the JSON state file produced by snapshot.py (schema resume-after-reboot/v1) and sends
each row's resume command into the matching tmux window. Dry-run by default; pass --go to
actually fire. The document is flat and tmux-shaped; the herdr-reboot plugin writes a nested
resume-after-reboot/v2 document instead, which this restore rejects rather than flattens.

Windows are matched by cwd, not by position: tmux-resurrect renumbers windows across a
reboot, so a positional lookup fires resume commands into the wrong windows. A row's `slot`
is a 1-based ordinal used for ordering, display, and --skip — never a window index. Each
row is paired with a live window whose current path equals the recorded cwd. A row is only
fired into a window sitting idle at a shell prompt with no live agent, so a mistargeted or
repeated run never types into a running program.

Usage:
    restore.py [state_file] [--go] [--skip SLOT]
Defaults state_file to .llm/resume-after-reboot-state.json and to dry-run.
The window running this process is fired last so it isn't disrupted mid-restore.
"""
import argparse, json, subprocess, sys, os

HOME = os.path.expanduser("~")
SHELLS = {"zsh", "bash", "sh", "fish", "dash", "ksh", "tcsh"}

SCHEMA = "resume-after-reboot/v1"
DEFAULT_STATE = ".llm/resume-after-reboot-state.json"


def sh(args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def basename(cmd):
    return cmd.split("/")[-1].lstrip("-") if cmd else ""


def load_state(state_file):
    """Return (document, rows that carry a real resume command).

    The schema check is what stops some other JSON file from being replayed as state.
    `shell` rows have nothing to run and drop out here.
    """
    try:
        with open(state_file) as fh:
            document = json.load(fh)
    except (OSError, ValueError) as e:
        sys.exit(f"{state_file}: not a readable JSON state file ({e})")
    if not isinstance(document, dict) or document.get("schema") != SCHEMA:
        found = document.get("schema") if isinstance(document, dict) else None
        sys.exit(f"{state_file}: expected schema {SCHEMA!r}, found {found!r}")
    rows = []
    for r in document.get("rows", []):
        if r.get("tool") == "shell" or not r.get("command"):
            continue
        rows.append({**r, "cwd": os.path.expanduser(r.get("cwd", ""))})
    return document, rows


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


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__.partition("Usage:")[0].strip(),
        epilog=f"Defaults the state file to {DEFAULT_STATE} and to dry-run.\n"
               f"The window running this process is fired last so it isn't disrupted "
               f"mid-restore.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("state", nargs="?", default=DEFAULT_STATE,
                        help="JSON state file to replay")
    parser.add_argument("--go", action="store_true",
                        help="actually send the resume commands (default: dry-run)")
    parser.add_argument("--skip", action="append", type=int, default=[], metavar="SLOT",
                        help="leave the row in this slot alone; repeatable")
    return parser.parse_args()


def main():
    args = parse_args()
    if not os.path.exists(args.state):
        sys.exit(f"state file not found: {args.state}")
    document, rows = load_state(args.state)
    skip_slots = set(args.skip)

    session = sh(["tmux", "display-message", "-p", "#{session_name}"]).strip() or "main"
    here = sh(["tmux", "display-message", "-p", "#{window_index}"]).strip()
    wins = live_windows(session)
    kids, cmd = proc_tree()

    # Any unclaimed window whose cwd matches, lowest index first for a stable pairing.
    claimed = set()
    plan, skips = [], []
    for r in rows:
        if r.get("slot") in skip_slots:
            skips.append((r, "skipped by --skip"))
            continue
        candidates = sorted((w for w, d in wins.items() if d["cwd"] == r["cwd"]), key=int)
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
    mode = "FIRING" if args.go else "DRY-RUN (pass --go to fire)"
    print(f"{mode}: {len(plan)} matched, {len(skips)} skipped, session {session}")
    print(f"state: backend {document.get('backend', '?')}, "
          f"captured {document.get('captured', '?')}\n")
    if not wins:
        print("  no live tmux windows to pair against -- is tmux running?\n")
    for win, r in plan:
        here_tag = "  (current, last)" if win == here else ""
        print(f"  {session}:{win:<4} {r['command']:<58} "
              f"@{r['cwd'].replace(HOME, '~')}  (slot {r.get('slot', '?')}){here_tag}")
        if args.go:
            sh(["tmux", "send-keys", "-t", f"{session}:{win}", r["command"], "Enter"])
    for r, why in skips:
        print(f"  SKIP  {r.get('name', ''):<20} {r['command']:<58} "
              f"@{r['cwd'].replace(HOME, '~')} -- {why}")
    if not args.go:
        print("\nNothing sent. Re-run with --go to resume these agents.")


if __name__ == "__main__":
    main()
