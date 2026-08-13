#!/usr/bin/env python3
"""Snapshot the current tmux session so claude/codex agents can be resumed after a reboot.

tmux-resurrect restores windows, panes, and cwds, but NOT the claude/codex processes
running inside them. This captures, per pane: the tool (claude/codex), its cwd, and the
exact session id to resume — resolved by matching the pane's cwd against the most
recently modified session transcript on disk.

The state file is a flat JSON document (schema resume-after-reboot/v1), one row per window.
The herdr-reboot plugin speaks a nested resume-after-reboot/v2 instead, which carries the
workspace, tab, and split structure tmux gets back from tmux-resurrect.

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
#
# Restore leaves these alone unless asked: a dev server frequently outlives the reboot that
# killed the agents, and re-running it just earns an EADDRINUSE against the process still
# holding the port.
FOREGROUND_ALLOW = {
    "just", "npm", "pnpm", "yarn", "bun", "vite", "next", "node", "deno",
    "cargo", "make", "gradle", "mvn", "tail", "watch", "watchexec",
    "python", "python3", "uvicorn", "flask", "rails", "ng", "turbo",
}

# Read-only viewers, safe to re-run verbatim. Unlike the dev servers above, none of these
# survives a reboot and none holds a port, so restore fires them by default.
#
# tig and lazygit are here by request: both are viewers by convention but can stage, commit,
# and push from inside the TUI, so a restored one is only as safe as what you then type at it.
VIEW_ALLOW = {
    "less", "more", "bat", "most", "man",
    "htop", "btop", "top", "glances", "btm",
    "tig", "lazygit",
}

# A pager is worth restoring only when it names a file. A bare one is draining a pipe whose
# writer died with the reboot, so re-running it would hang the pane waiting on stdin.
PAGERS = {"less", "more", "bat", "most"}

# git cannot go in VIEW_ALLOW as a program: that would also re-run `git push` and
# `git rebase --continue`. Only these subcommands are read-only enough to replay.
GIT_READ_ONLY = {
    "annotate", "blame", "cat-file", "describe", "diff", "grep", "log",
    "ls-files", "ls-tree", "reflog", "shortlog", "show", "status", "whatchanged",
}

# Global git options that swallow the following token, so the subcommand scan can skip past
# their values instead of mistaking one for the subcommand.
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}


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


def base_name(cmdline):
    return cmdline.split()[0].split("/")[-1] if cmdline else ""


def git_subcommand(cmdline):
    """The subcommand of a git command line, or None when it carries only global options."""
    tokens = cmdline.split()[1:]
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token in GIT_OPTIONS_WITH_VALUE:
            index += 2
            continue
        if token.startswith("-"):
            index += 1
            continue
        return token
    return None


def has_operand(cmdline):
    """True when the command line names something beyond its own flags."""
    return any(not token.startswith("-") for token in cmdline.split()[1:])


def descendants(pid, kids, cmd):
    """Every command line below pid, depth-first."""
    found = []
    for kid in kids.get(pid, []):
        found.append(cmd.get(kid, ""))
        found += descendants(kid, kids, cmd)
    return found


def find_dev_server(pid, kids, cmd):
    """Depth-first: the cmdline of the first allowlisted long-running child, or None."""
    for kid in kids.get(pid, []):
        c = cmd.get(kid, "")
        if base_name(c) in FOREGROUND_ALLOW:
            return c
        found = find_dev_server(kid, kids, cmd)
        if found:
            return found
    return None


def find_viewer(pid, kids, cmd):
    """Depth-first: the cmdline of the first read-only viewer child, or None.

    Kept separate from the dev-server walk so a nested process can never be reported in
    place of the one the user launched -- git's own alias expansion is a child of the
    alias, and returning that would restore the expansion rather than the alias.
    """
    for kid in kids.get(pid, []):
        c = cmd.get(kid, "")
        name = base_name(c)
        if name == "git":
            # An alias tells us nothing about what it does, so judge the expansion rather
            # than the name: git resolves an alias by re-execing itself out of git-core.
            # Restore still replays the alias as typed.
            resolved = next((d for d in descendants(kid, kids, cmd)
                             if base_name(d) == "git" and "git-core/" in d), None)
            return c if git_subcommand(resolved or c) in GIT_READ_ONLY else None
        if name in VIEW_ALLOW:
            if name in PAGERS and not has_operand(c):
                return None
            return c
        found = find_viewer(kid, kids, cmd)
        if found:
            return found
    return None


def find_command(pid, kids, cmd):
    """(command, restore_default) for the pane's foreground program, or None."""
    dev_server = find_dev_server(pid, kids, cmd)
    if dev_server:
        return dev_server, False
    viewer = find_viewer(pid, kids, cmd)
    return (viewer, True) if viewer else None


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


def row(slot, name, cwd, tool, command, session_id, note, restore_default=None):
    """One state-file row.

    `slot` is a 1-based ordinal for ordering and display, not a tmux window index —
    tmux-resurrect renumbers windows across a reboot, so restore pairs rows by cwd.
    `session_id` is broken out of `command` so consumers never re-parse the command
    string; it is null for `command`/`shell` rows and for the --continue/--last
    fallbacks, which carry no id. `note` records how the pairing was made, so a human
    can spot a weak one. `restore_default` appears only on `command` rows, marking the
    read-only viewers restore may replay without being asked.
    """
    built = {
        "slot": slot,
        "name": name,
        "tool": tool,
        "command": command,
        "cwd": cwd.replace(HOME, "~"),
        "session_id": session_id,
        "note": note,
    }
    if restore_default is not None:
        built["restore_default"] = restore_default
    return built


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
            found = find_command(int(ppid), kids, cmd)
            if found:
                c, restore_default = found
                note = "read-only; re-runs command" if restore_default \
                    else "best-effort; re-runs command"
                rows.append(row(slot, name, cwd, "command", c, None, note, restore_default))
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
