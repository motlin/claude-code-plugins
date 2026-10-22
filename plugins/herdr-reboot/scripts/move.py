#!/usr/bin/env python3
"""Move herdr workspaces or single tabs from one herdr session to another.

Each herdr session is its own server, so a pane cannot be handed across. A move is a snapshot of
the source session filtered down to the chosen workspaces and tabs, closed in the source, then
rebuilt in the target by restore.py: claude panes come back with `claude --resume <id>`, codex
with `codex resume <id>`, shells in the same cwd, and command panes re-run.

A SELECTOR is a workspace label (the whole workspace) or `workspace/tab` (one tab, which lands
in the target as its own workspace named after the tab).

Dry-run by default: prints what would be closed and restore's preview of the rebuild. With --go:
verify the target server is running, refuse if any selected pane is `working`, back up the full
source snapshot, close the selection in the source, restore it into the target, and summarize the
moved panes' agent status in the target.

Usage:
    move.py SELECTOR... --to SESSION [--from SESSION] [--go] [--no-commands]
"""
import argparse, json, os, subprocess, sys, time
from collections import Counter
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import restore  # noqa: E402
import snapshot  # noqa: E402
from snapshot import session_env  # noqa: E402

# How long resumed agents get to report a status before the summary reads them.
SETTLE_SECONDS = 3.0


class MoveError(Exception):
    pass


def caller_session(environ, session_list):
    """The session the caller runs in, matched by socket against `herdr session list` output."""
    socket = environ.get("HERDR_SOCKET_PATH")
    if socket:
        for line in session_list.splitlines()[1:]:
            fields = line.split()
            if len(fields) >= 2 and fields[-1] == socket:
                return fields[0]
    return environ.get("HERDR_SESSION") or "default"


def error_code(stdout):
    """The `error.code` of a herdr JSON envelope, or None."""
    try:
        return (json.loads(stdout).get("error") or {}).get("code")
    except (json.JSONDecodeError, AttributeError):
        return None


def one(found, what):
    if len(found) > 1:
        raise MoveError(f'"{what}" matches {len(found)} workspaces; rename one first')
    return found[0] if found else None


def resolve(workspaces, selector):
    """(workspace, tab or None) for a selector; a whole-label match beats a workspace/tab split."""
    workspace = one([w for w in workspaces if w["label"] == selector], selector)
    if workspace:
        return workspace, None
    for index, char in enumerate(selector):
        if char != "/":
            continue
        workspace = one([w for w in workspaces if w["label"] == selector[:index]], selector[:index])
        if not workspace:
            continue
        tabs = [t for t in workspace["tabs"] if t["label"] == selector[index + 1:]]
        if len(tabs) > 1:
            raise MoveError(f'"{selector}" matches {len(tabs)} tabs; rename one first')
        if tabs:
            return workspace, tabs[0]
    labels = ", ".join(w["label"] for w in workspaces)
    raise MoveError(f'no workspace or workspace/tab matches "{selector}"; workspaces: {labels}')


def wrap(workspace, tab):
    """A lone tab dressed as its own workspace, so restore rebuilds it as one."""
    return {"workspace_id": tab["tab_id"], "label": tab["label"], "number": 1,
            "active_tab_id": tab["tab_id"], "from_workspace": workspace["label"], "tabs": [tab]}


def filter_state(state, selectors, target):
    """(state holding only the selection, [(kind, id) to close in the source]), in source order."""
    workspaces = state.get("workspaces", [])
    whole, tabs = set(), set()
    for selector in selectors:
        workspace, tab = resolve(workspaces, selector)
        if tab:
            tabs.add(tab["tab_id"])
        else:
            whole.add(workspace["workspace_id"])

    chosen, closes = [], []
    for workspace in workspaces:
        if workspace["workspace_id"] in whole:
            chosen.append(workspace)
            closes.append(("workspace", workspace["workspace_id"]))
            continue
        for tab in workspace["tabs"]:
            if tab["tab_id"] in tabs:
                chosen.append(wrap(workspace, tab))
                closes.append(("tab", tab["tab_id"]))

    # restore reads focus with state.get("focus", {}).get(...), so it must stay a dict.
    focus = state.get("focus") or {}
    ids = {w["workspace_id"] for w in chosen}
    if focus.get("tab_id") in ids:
        focus = {**focus, "workspace_id": focus["tab_id"]}
    elif focus.get("workspace_id") not in ids:
        focus = {}
    return {**state, "session": target, "focus": focus, "workspaces": chosen}, closes


def moved_panes(state):
    """(where, leaf) for every pane in the state, `where` naming its source workspace and tab."""
    for workspace in state["workspaces"]:
        label = workspace.get("from_workspace", workspace["label"])
        for tab in workspace["tabs"]:
            for leaf in restore.leaves(tab["layout"]):
                yield f"{label} / {tab['label']}", leaf


def check_safety(state, statuses, caller_pane):
    """Warnings for blocked panes; raises MoveError for a working pane or the caller's own."""
    working, warnings = [], []
    for where, leaf in moved_panes(state):
        pane = leaf["pane_id"]
        if pane == caller_pane:
            raise MoveError(f"refusing to move pane {pane}: it is running this command; "
                            "run the move from a pane outside the selection")
        status = statuses.get(pane)
        if status == "working":
            working.append(f"  {where}  pane {pane}  {leaf['tool']}")
        elif status == "blocked":
            warnings.append(f"{where}  pane {pane}  {leaf['tool']} is blocked; "
                            "its pending prompt will be dropped")
    if working:
        raise MoveError("refusing to move panes that are working (closing them interrupts the "
                        "turn):\n" + "\n".join(working))
    return warnings


def summarize(snap, workspace_ids):
    """(tool, agent_status) -> pane count, over the panes in the given workspaces."""
    return dict(Counter((p.get("agent") or "shell", p.get("agent_status"))
                        for p in snap.get("panes", []) if p.get("workspace_id") in workspace_ids))


def herdr(args, env):
    return subprocess.run(["herdr"] + args, capture_output=True, text=True, env=env)


def require_running(session, env):
    probe = herdr(["api", "snapshot"], env)
    if probe.returncode == 0:
        return
    if "server_not_running" in (error_code(probe.stdout), error_code(probe.stderr)):
        raise MoveError(f'herdr session "{session}" is not running. Start it in a terminal with '
                        f"`herdr session attach {session}`, then re-run this move.")
    raise MoveError(f'cannot reach herdr session "{session}": '
                    f"{(probe.stdout or probe.stderr).strip()}")


def backup(state, source):
    directory = os.path.dirname(restore.DEFAULT_STATE)
    os.makedirs(directory, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = os.path.join(directory, f"herdr-move-backup-{source}-{stamp}.json")
    with open(path, "w") as fh:
        fh.write(json.dumps(snapshot.build_state([state]), indent=2) + "\n")
    return path


def move(args):
    caller = caller_session(os.environ, herdr(["session", "list"], None).stdout)
    source = args.source or caller
    if source == args.to:
        raise MoveError(f'source and target are both "{source}"')
    source_env, target_env = session_env(source, os.environ), session_env(args.to, os.environ)

    require_running(args.to, target_env)
    snapshot.HERDR_ENV = source_env
    snap = snapshot.live_snapshot()
    full = snapshot.build_session(snap, source)
    filtered, closes = filter_state(full, args.selectors, args.to)
    statuses = {p["pane_id"]: p.get("agent_status") for p in snap.get("panes", [])}
    caller_pane = os.environ.get("HERDR_PANE_ID") if source == caller else None
    warnings = check_safety(filtered, statuses, caller_pane)

    print(f'{"MOVING" if args.go else "DRY-RUN"}: {source} -> {args.to}')
    for kind, ident in closes:
        print(f"  close {kind} {ident} in {source}")
    for warning in warnings:
        print(f"  WARN  {warning}")
    print()

    restore.HERDR_ENV = target_env
    options = argparse.Namespace(go=args.go, no_commands=args.no_commands,
                                 delay=args.delay)
    if not args.go:
        restore.run(filtered, options)
        print(f"Nothing closed in {source}. Re-run with --go to move.")
        return

    print(f"Backed up {source} to {backup(full, source)}")
    for kind, ident in closes:
        closed = herdr([kind, "close", ident], source_env)
        if closed.returncode != 0:
            raise MoveError(f"herdr {kind} close {ident} failed: "
                            f"{(closed.stdout or closed.stderr).strip()}; nothing restored yet")
    restored = restore.run(filtered, options)

    time.sleep(SETTLE_SECONDS)
    result = json.loads(herdr(["api", "snapshot"], target_env).stdout or "{}").get("result") or {}
    counts = summarize(result.get("snapshot", {}),
                       {workspace_id for workspace_id, _ in restored.values() if workspace_id})
    print(f"\nIn {args.to} after {SETTLE_SECONDS:g}s:")
    for (tool, status), count in sorted(counts.items(), key=lambda item: (item[0][0], str(item[0][1]))):
        print(f"  {count:>3}  {tool:<8}{status}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("selectors", nargs="+", metavar="SELECTOR",
                        help="workspace label, or workspace/tab for a single tab")
    parser.add_argument("--to", required=True, help="session to move into")
    parser.add_argument("--from", dest="source",
                        help="session to move out of (default: the one this runs in)")
    parser.add_argument("--go", action="store_true", help="move, instead of previewing")
    parser.add_argument("--no-commands", action="store_true",
                        help="leave dev-server `command` panes at a shell in the target")
    parser.add_argument("--delay", type=float, default=0.4,
                        help="seconds between agent launches (default: 0.4)")
    try:
        move(parser.parse_args())
    except MoveError as exc:
        sys.exit(str(exc))


if __name__ == "__main__":
    main()
