#!/usr/bin/env python3
"""Snapshot the current tmux session so claude/codex agents can be resumed after a reboot.

tmux-resurrect restores windows, panes, and cwds, but NOT the claude/codex processes
running inside them. This captures, per pane: the tool (claude/codex), its cwd, and the
exact session id to resume — resolved by matching the pane's cwd against the most
recently modified session transcript on disk.

Usage:
    snapshot.py [tmux_session]        # prints a markdown table to stdout
Defaults to the attached tmux session. Redirect stdout to a state file, e.g.:
    snapshot.py > .llm/resume-after-reboot-state.md
"""
import subprocess, os, re, json, glob, sys
from datetime import datetime

HOME = os.path.expanduser("~")
CLAUDE_PROJECTS = os.path.join(HOME, ".claude", "projects")
CODEX_SESSIONS = os.path.join(HOME, ".codex", "sessions")


def sh(args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def attached_session():
    out = sh(["tmux", "display-message", "-p", "#{session_name}"]).strip()
    return out or "main"


def proc_tree():
    kids, cmd = {}, {}
    for line in sh(["/bin/ps", "-axo", "pid=,ppid=,command="]).splitlines():
        p = line.strip().split(None, 2)
        if len(p) < 3:
            continue
        pid, ppid, c = int(p[0]), int(p[1]), p[2]
        kids.setdefault(ppid, []).append(pid)
        cmd[pid] = c
    return kids, cmd


def find_tool(pid, kids, cmd):
    """Depth-first: return (kind, cmdline) of the claude/codex descendant, or None."""
    for k in kids.get(pid, []):
        c = cmd.get(k, "")
        base = c.split()[0].split("/")[-1] if c else ""
        if base == "claude":
            return ("claude", c)
        if "codex" in c and base in ("codex", "node"):
            return ("codex", c)
        r = find_tool(k, kids, cmd)
        if r:
            return r
    return None


def claude_slug_candidates(cwd):
    # claude replaces "/" with "-"; "." is sometimes kept, sometimes turned to "-".
    base = cwd.replace("/", "-")
    return {base, base.replace(".", "-")}


def latest_claude_sessions(cwd):
    files = []
    for slug in claude_slug_candidates(cwd):
        files += glob.glob(os.path.join(CLAUDE_PROJECTS, slug, "*.jsonl"))
    return sorted(set(files), key=os.path.getmtime, reverse=True)


def index_codex_sessions():
    """Map cwd -> [rollout files, newest first] by reading each rollout's session_meta."""
    recent = sorted(glob.glob(os.path.join(CODEX_SESSIONS, "*", "*", "*", "*.jsonl")),
                    key=os.path.getmtime, reverse=True)
    by_cwd = {}
    for f in recent[:400]:
        try:
            with open(f) as fh:
                meta = json.loads(fh.readline())
            cwd = meta.get("payload", {}).get("cwd")
            if cwd:
                by_cwd.setdefault(cwd, []).append(f)
        except Exception:
            continue
    return by_cwd


def uuid_in(name):
    m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", name)
    return m.group(0) if m else "?"


def mtime(path):
    return datetime.fromtimestamp(os.path.getmtime(path)).strftime("%Y-%m-%d %H:%M")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else attached_session()
    kids, cmd = proc_tree()
    codex_idx = index_codex_sessions()
    claude_used, codex_used = {}, {}

    panes = sh(["tmux", "list-panes", "-a",
                "-F", "#{session_name}|#{window_index}|#{window_name}|#{pane_pid}|#{pane_current_path}"])
    rows, seen_win = [], set()
    for line in panes.splitlines():
        sess, win, name, ppid, cwd = line.split("|")
        if sess != target or win in seen_win:
            continue
        seen_win.add(win)
        tool = find_tool(int(ppid), kids, cmd)
        if not tool:
            rows.append((win, name, cwd, "-", "idle shell", ""))
            continue
        kind, _ = tool
        if kind == "claude":
            s = latest_claude_sessions(cwd)
            i = claude_used.get(cwd, 0); claude_used[cwd] = i + 1
            if i < len(s):
                sid = os.path.basename(s[i]).replace(".jsonl", "")
                rows.append((win, name, cwd, kind, f"claude --resume {sid}", f"session mtime {mtime(s[i])}"))
            else:
                rows.append((win, name, cwd, kind, "claude --continue", "no transcript; --continue picks newest in cwd"))
        else:
            s = codex_idx.get(cwd, [])
            i = codex_used.get(cwd, 0); codex_used[cwd] = i + 1
            if i < len(s):
                rows.append((win, name, cwd, kind, f"codex resume {uuid_in(os.path.basename(s[i]))}", f"rollout mtime {mtime(s[i])}"))
            else:
                rows.append((win, name, cwd, kind, "codex resume --last", "no matching rollout for cwd"))

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"# tmux resume-after-reboot state\n")
    print(f"Captured: {now} (session `{target}`)\n")
    print("After reboot, tmux-resurrect restores windows + cwds. In each window below, run the")
    print("resume command to bring the agent back. Windows marked `idle shell` need nothing.\n")
    print("Session ids are resolved by newest-matching transcript for the cwd, so when one cwd")
    print("holds multiple live agents the pairing is best-effort — the set of ids is correct.\n")
    print("| Win | Name | Tool | Resume command | cwd | Note |")
    print("|----:|------|------|----------------|-----|------|")
    for win, name, cwd, kind, cmdc, note in rows:
        print(f"| {win} | {name} | {kind} | `{cmdc}` | {cwd.replace(HOME, '~')} | {note} |")


if __name__ == "__main__":
    main()
