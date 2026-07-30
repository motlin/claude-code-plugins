#!/usr/bin/env python3
"""Snapshot the current tmux session so claude/codex agents can be resumed after a reboot.

tmux-resurrect restores windows, panes, and cwds, but NOT the claude/codex processes
running inside them. This captures, per pane: the tool (claude/codex), its cwd, and the
exact session id to resume — resolved by matching the pane's cwd against the most
recently modified session transcript on disk.

The state file is a JSON document (schema resume-after-reboot/v1) shared with the
herdr-reboot plugin, so a snapshot taken here restores under either backend.

Usage:
    snapshot.py [tmux_session]        # prints the JSON document to stdout
Defaults to the attached tmux session. Redirect stdout to a state file, e.g.:
    snapshot.py > .llm/resume-after-reboot-state.json
"""
import argparse, subprocess, os, re, json, glob, sys
from datetime import datetime

HOME = os.path.expanduser("~")
CLAUDE_PROJECTS = os.path.join(HOME, ".claude", "projects")
CODEX_SESSIONS = os.path.join(HOME, ".codex", "sessions")

SCHEMA = "resume-after-reboot/v1"
BACKEND = "tmux"
DEFAULT_STATE = ".llm/resume-after-reboot-state.json"

# Long-running foreground commands worth re-running after a reboot. These carry no
# resumable session state (unlike claude/codex), so restoring one just re-executes the
# command line — best-effort. Bare shells with no such child stay `shell` rows.
FOREGROUND_ALLOW = {
    "just", "npm", "pnpm", "yarn", "bun", "vite", "next", "node", "deno",
    "cargo", "make", "gradle", "mvn", "tail", "watch", "watchexec",
    "python", "python3", "uvicorn", "flask", "rails", "ng", "turbo",
}


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


def find_command(pid, kids, cmd):
    """Depth-first: return the cmdline of the first allowlisted long-running child, or None."""
    for k in kids.get(pid, []):
        c = cmd.get(k, "")
        base = c.split()[0].split("/")[-1] if c else ""
        if base in FOREGROUND_ALLOW:
            return c
        r = find_command(k, kids, cmd)
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


def row(slot, name, cwd, tool, command, session_id, note):
    """One state-file row.

    `slot` is a 1-based ordinal for ordering and display, not a tmux window index —
    tmux-resurrect renumbers windows across a reboot, so restore pairs rows by cwd.
    `session_id` is broken out of `command` so consumers never re-parse the command
    string; it is null for `command`/`shell` rows and for the --continue/--last
    fallbacks, which carry no id. `note` records how the pairing was made, so a human
    can spot a weak one.
    """
    return {
        "slot": slot,
        "name": name,
        "tool": tool,
        "command": command,
        "cwd": cwd.replace(HOME, "~"),
        "session_id": session_id,
        "note": note,
    }


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__.partition("Usage:")[0].strip(),
        epilog=f"Redirect stdout or pass --output to write the state file, "
               f"conventionally {DEFAULT_STATE}.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("session", nargs="?",
                        help="tmux session to snapshot (default: the attached session)")
    parser.add_argument("--output", metavar="PATH",
                        help="write the JSON document here instead of stdout")
    return parser.parse_args()


def main():
    args = parse_args()
    target = args.session or attached_session()
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
        slot = len(rows) + 1
        tool = find_tool(int(ppid), kids, cmd)
        if not tool:
            c = find_command(int(ppid), kids, cmd)
            if c:
                rows.append(row(slot, name, cwd, "command", c, None, "best-effort; re-runs command"))
            else:
                rows.append(row(slot, name, cwd, "shell", None, None, ""))
            continue
        kind, _ = tool
        if kind == "claude":
            s = latest_claude_sessions(cwd)
            i = claude_used.get(cwd, 0); claude_used[cwd] = i + 1
            if i < len(s):
                sid = os.path.basename(s[i]).replace(".jsonl", "")
                rows.append(row(slot, name, cwd, kind, f"claude --resume {sid}", sid, f"session mtime {mtime(s[i])}"))
            else:
                rows.append(row(slot, name, cwd, kind, "claude --continue", None, "no transcript; --continue picks newest in cwd"))
        else:
            s = codex_idx.get(cwd, [])
            i = codex_used.get(cwd, 0); codex_used[cwd] = i + 1
            if i < len(s):
                sid = uuid_in(os.path.basename(s[i]))
                rows.append(row(slot, name, cwd, kind, f"codex resume {sid}",
                                sid if sid != "?" else None, f"rollout mtime {mtime(s[i])}"))
            else:
                rows.append(row(slot, name, cwd, kind, "codex resume --last", None, "no matching rollout for cwd"))

    document = {
        "schema": SCHEMA,
        "captured": datetime.now().astimezone().isoformat(timespec="seconds"),
        "backend": BACKEND,
        "session": target,
        "rows": rows,
    }
    text = json.dumps(document, indent=2) + "\n"
    if args.output:
        with open(args.output, "w") as fh:
            fh.write(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
