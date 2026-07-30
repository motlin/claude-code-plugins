#!/usr/bin/env python3
"""Restore claude/codex agents from a herdr-reboot snapshot by rebuilding workspaces and tabs.

Reads a `resume-after-reboot/v1` state file (written by this plugin's snapshot.py, or by the
tmux-reboot plugin — the schema is shared) and rebuilds it as herdr workspaces and tabs: one
workspace per distinct cwd in first-appearance order, one tab per row in slot order. Dry-run by
default; pass --go to actually create and fire.

`herdr pane run` types into whatever the pane currently holds — there is no idle-shell guard in
herdr itself. Firing into a pane that already held a resumed claude submits the text as a PROMPT
to that agent and pollutes a real conversation. So every row is fired only into a pane confirmed
to be sitting at an idle shell with no live agent, which also makes re-running this script safe.
For the same reason an existing workspace with a matching cwd is adopted rather than duplicated,
but each of its rows still gets a brand new tab, so a live agent pane is never reused.

`command` rows (dev servers and watchers like `just dev`) are NOT fired unless --commands is
passed: those processes often survive the reboot that killed the agents, and re-running them just
produces EADDRINUSE against the server still holding the port. Their tab is still created.

Usage:
    restore.py [state_file] [--go] [--limit N] [--skip SLOT[,SLOT...]] [--commands]
Defaults state_file to .llm/resume-after-reboot-state.json and to dry-run.
"""
import argparse, json, os, shlex, subprocess, sys, time

HOME = os.path.expanduser("~")
SCHEMA = "resume-after-reboot/v1"
DEFAULT_STATE = ".llm/resume-after-reboot-state.json"
AGENT_TOOLS = ("claude", "codex")

# How long to wait for a freshly created tab's shell to come up before giving up on it.
IDLE_TIMEOUT_SECONDS = 2.0
IDLE_POLL_SECONDS = 0.1


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


def herdr_run(args):
    """Run a herdr command that answers with nothing. Exit 0 and empty stdout IS success."""
    return sh(["herdr"] + args).returncode == 0


def load_state(path):
    if not os.path.exists(path):
        sys.exit(f"state file not found: {path}")
    try:
        with open(path) as fh:
            state = json.load(fh)
    except json.JSONDecodeError as exc:
        sys.exit(f"{path} is not valid JSON: {exc}")
    schema = state.get("schema")
    if schema != SCHEMA:
        sys.exit(f"{path} has schema {schema!r}; expected {SCHEMA!r}")
    return state


def expand(cwd):
    return os.path.join(HOME, cwd[2:]) if cwd.startswith("~/") else os.path.expanduser(cwd)


def tilde(path):
    return path.replace(HOME, "~", 1) if path.startswith(HOME) else path


def program_name(proc):
    """The tool a process represents: basename of argv0, with node-hosted codex unwrapped."""
    argv = proc.get("argv") or []
    raw = proc.get("argv0") or (argv[0] if argv else "")
    base = os.path.basename(raw).lstrip("-")
    if base in ("node", "bun") and "codex" in (proc.get("cmdline") or ""):
        return "codex"
    return base


def leader_process(info):
    pgid = info.get("foreground_process_group_id")
    procs = info.get("foreground_processes") or []
    for proc in procs:
        if proc.get("pid") == pgid:
            return proc
    return procs[-1] if procs else None


def live_state():
    """(workspace_id -> cwd in workspace order, pane_id -> live agent)."""
    result = herdr_json(["api", "snapshot"])
    if not result or "snapshot" not in result:
        sys.exit("herdr api snapshot returned no state; is the herdr server running?")
    snap = result["snapshot"]
    tab_order = {t["tab_id"]: t.get("number", 0) for t in snap.get("tabs", [])}
    panes = sorted(snap.get("panes", []), key=lambda p: tab_order.get(p.get("tab_id"), 0))
    cwds = {}
    for pane in panes:
        cwds.setdefault(pane.get("workspace_id"), pane.get("cwd"))
    workspaces = {}
    for ws in sorted(snap.get("workspaces", []), key=lambda w: w.get("number", 0)):
        workspaces[ws["workspace_id"]] = cwds.get(ws["workspace_id"])
    agents = {p.get("pane_id"): p.get("agent") for p in panes if p.get("agent")}
    return workspaces, agents, snap.get("focused_workspace_id")


def block_reason(pane_id, agents):
    """None when the pane is safe to type into, else a printable reason to skip it."""
    if agents.get(pane_id):
        return f"pane {pane_id} already has a live {agents[pane_id]}"
    deadline = time.monotonic() + IDLE_TIMEOUT_SECONDS
    reason = f"pane {pane_id} reported no process info"
    while True:
        result = herdr_json(["pane", "process-info", "--pane", pane_id])
        info = (result or {}).get("process_info")
        if info:
            if info.get("foreground_process_group_id") == info.get("shell_pid"):
                return None
            leader = leader_process(info)
            running = program_name(leader) if leader else "something"
            reason = f"pane {pane_id} is running {running}, not an idle shell"
            if running in AGENT_TOOLS:
                return reason
        if time.monotonic() >= deadline:
            return reason
        time.sleep(IDLE_POLL_SECONDS)


def tab_label(row):
    if row["tool"] in AGENT_TOOLS:
        session = row.get("session_id")
        return f"{row['tool']} {session[:8]}" if session else row["tool"]
    return row["command"] if row["tool"] == "command" else "shell"


def select_rows(state, limit, skip):
    """Rows in slot order, minus --skip slots, grouped into (cwd, label, rows) workspaces."""
    rows = [r for r in sorted(state.get("rows", []), key=lambda r: r.get("slot", 0))
            if r.get("slot") not in skip]
    groups, index = [], {}
    for row in rows:
        cwd = expand(row["cwd"])
        if cwd not in index:
            index[cwd] = len(groups)
            groups.append({"cwd": cwd, "label": row["name"], "rows": []})
        groups[index[cwd]]["rows"].append(row)
    return groups[:limit] if limit else groups


def create_workspace(group):
    result = herdr_json(["workspace", "create", "--cwd", group["cwd"],
                         "--label", group["label"], "--no-focus"])
    if not result:
        return None
    return result.get("root_pane", {}).get("pane_id"), result.get("workspace", {}).get("workspace_id")


def create_tab(workspace_id, group, label):
    result = herdr_json(["tab", "create", "--workspace", workspace_id,
                         "--cwd", group["cwd"], "--label", label, "--no-focus"])
    if not result:
        return None
    return result.get("root_pane", {}).get("pane_id")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("state", nargs="?", default=DEFAULT_STATE,
                        help=f"state file to restore (default: {DEFAULT_STATE})")
    parser.add_argument("--go", action="store_true", help="create and fire, instead of previewing")
    parser.add_argument("--limit", type=int, help="restore only the first N workspaces")
    parser.add_argument("--skip", default="", help="comma-separated slots to leave out entirely")
    parser.add_argument("--commands", action="store_true",
                        help="also re-run `command` rows, which are skipped by default")
    parser.add_argument("--delay", type=float, default=0.4,
                        help="seconds between agent launches (default: 0.4)")
    args = parser.parse_args()

    skip = {int(s) for s in args.skip.split(",") if s.strip()}
    state = load_state(args.state)
    groups = select_rows(state, args.limit, skip)
    workspaces, agents, focused = live_state()

    tabs = sum(len(g["rows"]) for g in groups)
    firing = [r for g in groups for r in g["rows"]
              if r["tool"] in AGENT_TOOLS or (r["tool"] == "command" and args.commands)]
    quiet = tabs - len(firing)
    mode = "FIRING" if args.go else "DRY-RUN (pass --go to fire)"
    print(f"{mode}: {len(groups)} workspaces, {tabs} tabs, "
          f"{len(firing)} rows to fire, {quiet} not fired\n")

    fired, skipped = 0, 0
    for group in groups:
        adopted = next((wid for wid, cwd in workspaces.items() if cwd == group["cwd"]), None)
        how = f"adopt {adopted}" if adopted else "create"
        print(f"  workspace \"{group['label']}\" @{tilde(group['cwd'])}  ({how})")

        workspace_id, root_pane = adopted, None
        if args.go and not adopted:
            created = create_workspace(group)
            if not created:
                print(f"    SKIP  workspace \"{group['label']}\" -- herdr workspace create failed")
                skipped += len(group["rows"])
                continue
            root_pane, workspace_id = created

        for row in group["rows"]:
            label = tab_label(row)
            slot = row.get("slot")
            target = f"slot {slot:<3} {row['tool']:<8}{row['command'] or '-'}"
            if row["tool"] == "command" and not args.commands:
                print(f"    SKIP  {target} -- command row; pass --commands to re-run it")
                continue
            if not args.go:
                print(f"    {target}  -> tab \"{label}\"")
                continue

            # The workspace's own root pane serves its first row; every other row, including
            # every row of an adopted workspace, gets a brand new tab so no live pane is reused.
            pane = root_pane or create_tab(workspace_id, group, label)
            root_pane = None
            if not pane:
                print(f"    SKIP  {target} -- herdr tab create failed")
                skipped += 1
                continue
            if row["tool"] == "shell":
                print(f"    {target}  -> tab \"{label}\" pane {pane}")
                continue
            reason = block_reason(pane, agents)
            if reason:
                print(f"    SKIP  {target} -- {reason}")
                skipped += 1
                continue
            if not herdr_run(["pane", "run", pane] + shlex.split(row["command"])):
                print(f"    SKIP  {target} -- herdr pane run failed")
                skipped += 1
                continue
            print(f"    {target}  -> pane {pane}")
            fired += 1
            if args.delay:
                time.sleep(args.delay)

    if args.go:
        if focused:
            herdr_run(["workspace", "focus", focused])
        print(f"\nFired {fired} of {len(firing)} rows; {skipped} skipped.")
    else:
        print("\nNothing sent. Re-run with --go to restore these workspaces.")


if __name__ == "__main__":
    main()
