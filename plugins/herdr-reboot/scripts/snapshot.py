#!/usr/bin/env python3
"""Snapshot the running herdr session so claude/codex agents can be resumed after a reboot.

Nothing survives a reboot: the workspaces, the tabs, and the agents inside them all go away.
This captures, per pane, the tool (claude/codex), its cwd, and the exact session id to resume.

herdr makes this strictly better than the tmux-reboot snapshot. There, every claude session id
is *guessed* by matching a pane's cwd against the most recently modified transcript on disk.
Here, `herdr api snapshot` reports each claude pane's REAL session id, so claude rows involve no
transcript-mtime guessing at all.

herdr's codex integration is less complete: it leaves `agent_session` null until that pane takes
a turn (claude's hook reports on resume). Codex panes with no reported session therefore fall
back to the same cwd -> rollout index that tmux-reboot uses, and say so in the row's note.

The state file is JSON, schema `resume-after-reboot/v1`, shared verbatim with the tmux-reboot
plugin so either plugin's restore can read the other's snapshot.

Usage:
    snapshot.py [--output PATH] [--session NAME]
Prints the state JSON to stdout unless --output is given, e.g.:
    snapshot.py > .llm/resume-after-reboot-state.json
"""
import argparse, glob, json, os, re, subprocess, sys
from datetime import datetime

HOME = os.path.expanduser("~")
CODEX_SESSIONS = os.path.join(HOME, ".codex", "sessions")
SCHEMA = "resume-after-reboot/v1"

SHELLS = {"zsh", "bash", "sh", "fish", "dash", "ksh", "tcsh"}

# Long-running foreground commands worth re-running after a reboot. These carry no resumable
# session state (unlike claude/codex), so restoring one just re-executes the command line —
# best-effort. Panes running anything else are recorded as plain shells.
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
    return subprocess.run(args, capture_output=True, text=True)


def herdr_json(args):
    """Run a herdr command that answers with a JSON envelope and return its `result`."""
    p = sh(["herdr"] + args)
    if p.returncode != 0 or not p.stdout.strip():
        return None
    try:
        return json.loads(p.stdout).get("result")
    except json.JSONDecodeError:
        return None


def live_snapshot():
    result = herdr_json(["api", "snapshot"])
    if not result or "snapshot" not in result:
        sys.exit("herdr api snapshot returned no state; is the herdr server running?")
    return result["snapshot"]


def running_session():
    """The name of the running herdr session, per `herdr session list`."""
    p = sh(["herdr", "session", "list"])
    for line in p.stdout.splitlines()[1:]:
        fields = line.split()
        if len(fields) >= 2 and fields[1] == "running":
            return fields[0]
    return "default"


def program_name(proc):
    """The tool a process represents: basename of argv0, with node-hosted codex unwrapped."""
    argv = proc.get("argv") or []
    raw = proc.get("argv0") or (argv[0] if argv else "")
    base = os.path.basename(raw).lstrip("-")
    if base in ("node", "bun") and "codex" in (proc.get("cmdline") or ""):
        return "codex"
    return base


def process_info(pane_id):
    result = herdr_json(["pane", "process-info", "--pane", pane_id])
    return (result or {}).get("process_info")


def leader_process(info):
    """The foreground process group leader — the program the pane is actually running."""
    pgid = info.get("foreground_process_group_id")
    procs = info.get("foreground_processes") or []
    for proc in procs:
        if proc.get("pid") == pgid:
            return proc
    return procs[-1] if procs else None


def cmdline_of(proc):
    return proc.get("cmdline") or " ".join(proc.get("argv") or [])


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


def classify(leader, processes):
    """(command, restore_default) for a pane's foreground program, or None for a shell row."""
    for proc in [leader] + list(processes):
        if proc and program_name(proc) in FOREGROUND_ALLOW:
            return cmdline_of(proc), False

    if leader is None:
        return None
    name = program_name(leader)
    cmdline = cmdline_of(leader)
    if not cmdline:
        return None

    if name == "git":
        # An alias tells us nothing about what it does, so judge the expansion rather than
        # the name: git resolves an alias by re-execing itself out of git-core, leaving the
        # expansion as a sibling process. Restore still replays the alias as typed.
        resolved = next((proc for proc in processes
                         if program_name(proc) == "git" and "git-core/" in cmdline_of(proc)), None)
        subcommand = git_subcommand(cmdline_of(resolved) if resolved else cmdline)
        return (cmdline, True) if subcommand in GIT_READ_ONLY else None

    if name in VIEW_ALLOW:
        if name in PAGERS and not has_operand(cmdline):
            return None
        return cmdline, True

    return None


def find_command(pane_id):
    """(command, restore_default) for the pane's foreground program, or None."""
    info = process_info(pane_id)
    if not info:
        return None
    if info.get("foreground_process_group_id") == info.get("shell_pid"):
        return None
    return classify(leader_process(info), info.get("foreground_processes") or [])


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
    return m.group(0) if m else None


def mtime(path):
    return datetime.fromtimestamp(os.path.getmtime(path)).strftime("%Y-%m-%d %H:%M")


def tilde(path):
    return path.replace(HOME, "~", 1) if path.startswith(HOME) else path


def ordered_panes(snap):
    """Panes grouped by workspace order, then tab order, so slots follow the visual layout."""
    ws_order = {w["workspace_id"]: w.get("number", 0) for w in snap.get("workspaces", [])}
    tab_order = {t["tab_id"]: t.get("number", 0) for t in snap.get("tabs", [])}
    return sorted(snap.get("panes", []),
                  key=lambda p: (ws_order.get(p.get("workspace_id"), 0),
                                 tab_order.get(p.get("tab_id"), 0),
                                 p.get("pane_id", "")))


def reported_session(pane):
    session = pane.get("agent_session") or {}
    return session.get("value")


def build_rows(snap):
    labels = {w["workspace_id"]: w.get("label") or w["workspace_id"]
              for w in snap.get("workspaces", [])}
    codex_idx = index_codex_sessions()
    codex_used = {}
    rows = []
    for pane in ordered_panes(snap):
        cwd = pane.get("cwd") or HOME
        row = {
            "slot": len(rows) + 1,
            "name": labels.get(pane.get("workspace_id"), pane.get("workspace_id", "")),
            "tool": "shell",
            "command": None,
            "cwd": tilde(cwd),
            "session_id": None,
            "note": "",
        }
        agent = pane.get("agent")
        session_id = reported_session(pane)
        if agent == "claude":
            row.update(tool="claude", note="session id reported by herdr")
            if session_id:
                row.update(command=f"claude --resume {session_id}", session_id=session_id)
            else:
                row.update(command="claude --continue",
                           note="no session reported; --continue picks newest in cwd")
        elif agent == "codex":
            row.update(tool="codex")
            if session_id:
                row.update(command=f"codex resume {session_id}", session_id=session_id,
                           note="session id reported by herdr")
            else:
                # herdr's codex integration reports nothing until the pane takes a turn, so
                # match the cwd against recent rollouts the way tmux-reboot does.
                rollouts = codex_idx.get(cwd, [])
                i = codex_used.get(cwd, 0)
                codex_used[cwd] = i + 1
                found = uuid_in(os.path.basename(rollouts[i])) if i < len(rollouts) else None
                if found:
                    row.update(command=f"codex resume {found}", session_id=found,
                               note=f"herdr reported no session; rollout mtime {mtime(rollouts[i])}")
                else:
                    row.update(command="codex resume --last",
                               note="herdr reported no session and no matching rollout for cwd")
        else:
            found = find_command(pane.get("pane_id", ""))
            if found:
                command, restore_default = found
                row.update(tool="command", command=command, restore_default=restore_default,
                           note="read-only; re-runs command" if restore_default
                                else "best-effort; re-runs command")
        rows.append(row)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", help="write the state JSON here instead of stdout")
    parser.add_argument("--session", help="session name to record (default: the running one)")
    args = parser.parse_args()

    snap = live_snapshot()
    state = {
        "schema": SCHEMA,
        "captured": datetime.now().astimezone().isoformat(timespec="seconds"),
        "backend": "herdr",
        "session": args.session or running_session(),
        "rows": build_rows(snap),
    }
    text = json.dumps(state, indent=2) + "\n"
    if args.output:
        with open(args.output, "w") as fh:
            fh.write(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
