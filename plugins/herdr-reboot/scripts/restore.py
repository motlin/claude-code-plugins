#!/usr/bin/env python3
"""Restore a herdr session from a snapshot, rebuilding its workspaces, tabs, splits, and agents.

Reads a `resume-after-reboot/v2` state file written by this plugin's snapshot.py and rebuilds the
tree it describes: one workspace per captured workspace with its label, one tab per captured tab
with its label, the panes inside each tab split at the captured direction and ratio, then the
captured focus and zoom. Dry-run by default; pass --go to actually create and fire.

The document is herdr-shaped. An older flat `resume-after-reboot/v1` document has no workspaces,
tabs, or splits to rebuild, so it is rejected rather than half-restored.

`herdr pane run` types into whatever the pane currently holds — there is no idle-shell guard in
herdr itself. Firing into a pane that already held a resumed claude submits the text as a PROMPT
to that agent and pollutes a real conversation. So every pane is fired only into one confirmed to
be sitting at an idle shell with no live agent, which also makes re-running this script safe.

herdr can bring a session back by itself, agents included, leaving only the command panes
idle. So a live workspace matching a captured one is adopted, and each captured tab is paired with
the live tab of the same label and layout: its idle panes are fired into in place, and a pane
already running its agent is reported as such. Only a captured tab with no live counterpart is
created fresh.

`command` panes (dev servers like `just dev`, viewers like `git la`) are fired by default, since
bringing them back is most of what a restore is for. --no-commands leaves the dev servers alone,
for when one outlived the reboot and still holds its port.

Usage:
    restore.py [state_file] [--go] [--limit N] [--skip SLOT[,SLOT...]] [--no-commands]
Defaults state_file to .llm/resume-after-reboot-state.json and to dry-run.
"""
import argparse, json, os, shlex, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from snapshot import layout_tree  # noqa: E402

HOME = os.path.expanduser("~")
SCHEMA = "resume-after-reboot/v2"
DEFAULT_STATE = ".llm/resume-after-reboot-state.json"
AGENT_TOOLS = ("claude", "claude-rc", "codex")

# How long to wait for a freshly created pane's shell to come up before giving up on it.
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
    """((label, cwd) -> workspace_id, pane_id -> live agent, workspace_id -> its live tabs)."""
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
        workspaces[(ws.get("label"), cwds.get(ws["workspace_id"]))] = ws["workspace_id"]
    agents = {p.get("pane_id"): p.get("agent") for p in panes if p.get("agent")}
    return workspaces, agents, live_tabs(snap)


def live_tabs(snap):
    """workspace_id -> [{tab_id, label, panes in layout order, shape}], in tab order."""
    layouts = {layout["tab_id"]: layout for layout in snap.get("layouts", [])}
    tabs = {}
    for tab in sorted(snap.get("tabs", []), key=lambda t: t.get("number", 0)):
        layout = layouts.get(tab["tab_id"])
        if layout and layout.get("panes"):
            tree = layout_tree(layout, lambda pane_id: {"type": "pane", "pane_id": pane_id})
        else:
            first = next((p["pane_id"] for p in snap.get("panes", [])
                          if p.get("tab_id") == tab["tab_id"]), None)
            tree = {"type": "pane", "pane_id": first}
        tabs.setdefault(tab["workspace_id"], []).append(
            {"tab_id": tab["tab_id"], "label": tab.get("label"),
             "panes": [leaf["pane_id"] for leaf in leaves(tree)], "shape": shape(tree)})
    return tabs


def shape(node):
    """A layout's split structure, ignoring ratios and panes, to tell two layouts apart."""
    if node["type"] == "pane":
        return "pane"
    return (node["direction"], shape(node["children"][0]), shape(node["children"][1]))


def pair_tabs(tabs, live):
    """captured tab_id -> (live tab_id, captured pane_id -> live pane_id).

    Each live tab answers for at most one captured tab: the first, in order, with its label and
    the same split structure. A captured tab left unpaired is created fresh.
    """
    paired, used = {}, set()
    for tab in tabs:
        captured = leaves(tab["layout"])
        for candidate in live:
            if candidate["tab_id"] in used or candidate["label"] != tab["label"]:
                continue
            if candidate["shape"] != shape(tab["layout"]):
                continue
            used.add(candidate["tab_id"])
            paired[tab["tab_id"]] = (candidate["tab_id"],
                                     {leaf["pane_id"]: pane
                                      for leaf, pane in zip(captured, candidate["panes"])})
            break
    return paired


def leaves(node):
    """Every pane of a layout node, in the order the panes are laid out."""
    if node["type"] == "pane":
        return [node]
    return [leaf for child in node["children"] for leaf in leaves(child)]


def prune(node, skip):
    """The layout minus the skipped slots, with any split left holding one child collapsed."""
    if node["type"] == "pane":
        return None if node["slot"] in skip else node
    kept = [child for child in (prune(child, skip) for child in node["children"]) if child]
    if len(kept) < 2:
        return kept[0] if kept else None
    return {**node, "children": kept}


def select(state, limit, skip):
    """The captured workspaces, minus skipped panes and the tabs and workspaces they empty."""
    chosen = []
    for workspace in state.get("workspaces", []):
        tabs = []
        for tab in workspace.get("tabs", []):
            layout = prune(tab["layout"], skip)
            if layout:
                tabs.append({**tab, "layout": layout})
        if tabs:
            chosen.append({**workspace, "tabs": tabs})
    return chosen[:limit] if limit else chosen


def fires_by_default(leaf):
    """True when a `command` pane is a read-only viewer rather than a dev server."""
    return bool(leaf.get("restore_default"))


def will_fire(leaf, no_commands):
    if leaf["tool"] in AGENT_TOOLS:
        return True
    return leaf["tool"] == "command" and (not no_commands or fires_by_default(leaf))


def already_running(leaf, pane, agents):
    """True when an agent pane's live counterpart already holds a live agent."""
    return leaf["tool"] in AGENT_TOOLS and bool(agents.get(pane))


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


def create_workspace(label, cwd):
    result = herdr_json(["workspace", "create", "--cwd", cwd, "--label", label, "--no-focus"])
    if not result:
        return None
    return (result.get("workspace", {}).get("workspace_id"),
            result.get("tab", {}).get("tab_id"),
            result.get("root_pane", {}).get("pane_id"))


def create_tab(workspace_id, label, cwd):
    result = herdr_json(["tab", "create", "--workspace", workspace_id, "--cwd", cwd,
                         "--label", label, "--no-focus"])
    if not result:
        return None
    return result.get("tab", {}).get("tab_id"), result.get("root_pane", {}).get("pane_id")


def split_pane(pane_id, node, cwd, focus):
    result = herdr_json(["pane", "split", "--pane", pane_id,
                         "--direction", node["direction"], "--ratio", str(node["ratio"]),
                         "--cwd", cwd, "--focus" if focus else "--no-focus"])
    return (result or {}).get("pane", {}).get("pane_id")


def describe(leaf):
    return f"slot {leaf['slot']:<3} {leaf['tool']:<8}{leaf['command'] or '-'}"


class Restorer:
    """Rebuilds the captured tree, reporting each pane as it goes."""

    def __init__(self, args, agents, paired):
        self.args = args
        self.agents = agents
        self.paired = paired
        self.fired = 0
        self.skipped = 0
        self.running = 0
        # The pane now holding the tab's captured focused pane, once the walk reaches it.
        self.focused = None

    def report(self, depth, text):
        print(f"{'  ' * depth}{text}")

    def build_layout(self, node, pane, tab, depth):
        """Split `pane` until the captured layout is rebuilt, firing into each pane it makes."""
        if node["type"] == "pane":
            self.serve(node, pane, tab, depth)
            return
        self.report(depth, f"split {node['direction']} {node['ratio']}")
        second = leaves(node["children"][1])[0]
        made = pane
        if self.args.go:
            made = split_pane(pane, node, expand(second["cwd"]),
                              second["pane_id"] == tab.get("focused_pane_id"))
            if not made:
                self.report(depth + 1, "SKIP  herdr pane split failed")
                self.skipped += len(leaves(node["children"][1]))
                self.build_layout(node["children"][0], pane, tab, depth + 1)
                return
        self.build_layout(node["children"][0], pane, tab, depth + 1)
        self.build_layout(node["children"][1], made, tab, depth + 1)

    def serve(self, leaf, pane, tab, depth):
        """Fire a pane's command into the pane now holding it, when it is one worth firing."""
        if leaf["pane_id"] == tab.get("focused_pane_id"):
            self.focused = pane
        target = describe(leaf)
        if already_running(leaf, pane, self.agents):
            self.report(depth, f"LIVE  {target} -- pane {pane} already runs {self.agents[pane]}")
            self.running += 1
            return
        if leaf["tool"] == "command" and not will_fire(leaf, self.args.no_commands):
            self.report(depth, f"SKIP  {target} -- command pane left alone by --no-commands")
            return
        if not self.args.go:
            self.report(depth, target)
            return
        if leaf["tool"] == "shell":
            self.report(depth, f"{target}  -> pane {pane}")
            return
        reason = block_reason(pane, self.agents)
        if reason:
            self.report(depth, f"SKIP  {target} -- {reason}")
            self.skipped += 1
            return
        if not herdr_run(["pane", "run", pane] + shlex.split(leaf["command"])):
            self.report(depth, f"SKIP  {target} -- herdr pane run failed")
            self.skipped += 1
            return
        self.report(depth, f"{target}  -> pane {pane}")
        self.fired += 1
        if self.args.delay:
            time.sleep(self.args.delay)

    def build_tab(self, tab, workspace_id, root):
        """(tab id, pane holding the tab's focused pane) — root is the workspace's own tab."""
        cwd = expand(leaves(tab["layout"])[0]["cwd"])
        self.focused = None
        if tab["tab_id"] in self.paired:
            live_tab, panes = self.paired[tab["tab_id"]]
            self.report(2, f'tab "{tab["label"]}"  (live {live_tab})')
            for leaf in leaves(tab["layout"]):
                self.serve(leaf, panes[leaf["pane_id"]], tab, 3)
            return live_tab
        self.report(2, f'tab "{tab["label"]}"')
        tab_id, pane = root or (None, None)
        if self.args.go:
            if root:
                herdr_run(["tab", "rename", tab_id, tab["label"]])
            else:
                made = create_tab(workspace_id, tab["label"], cwd)
                if not made:
                    self.report(3, "SKIP  herdr tab create failed")
                    self.skipped += len(leaves(tab["layout"]))
                    return None
                tab_id, pane = made
        self.build_layout(tab["layout"], pane, tab, 3)
        if self.args.go and tab.get("zoomed") and self.focused:
            herdr_run(["pane", "zoom", "--pane", self.focused, "--on"])
        return tab_id

    def build_workspace(self, workspace, adopted):
        """The id of the rebuilt workspace and of the tab that should be active in it."""
        label, tabs = workspace["label"], workspace["tabs"]
        cwd = expand(leaves(tabs[0]["layout"])[0]["cwd"])
        how = f"adopt {adopted}" if adopted else "create"
        self.report(1, f'workspace "{label}" @{tilde(cwd)}  ({how})')

        workspace_id, root = adopted, None
        if self.args.go and not adopted:
            created = create_workspace(label, cwd)
            if not created:
                self.report(2, f'SKIP  workspace "{label}" -- herdr workspace create failed')
                self.skipped += sum(len(leaves(tab["layout"])) for tab in tabs)
                return None, None
            workspace_id, tab_id, pane = created
            root = (tab_id, pane)

        active = None
        for tab in tabs:
            built = self.build_tab(tab, workspace_id, root)
            root = None
            if built and tab["tab_id"] == workspace.get("active_tab_id"):
                active = built
        return workspace_id, active


def restore_focus(state, restored, go):
    """Put focus back where the snapshot found it: each workspace's active tab, then the session's
    focused workspace. Focus inside a tab is already set, by splitting its focused pane last."""
    if not go:
        return
    focused = state.get("focus", {}).get("workspace_id")
    for captured_id, (workspace_id, active_tab) in restored.items():
        if active_tab:
            herdr_run(["tab", "focus", active_tab])
        if captured_id == focused and workspace_id:
            herdr_run(["workspace", "focus", workspace_id])


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("state", nargs="?", default=DEFAULT_STATE,
                        help=f"state file to restore (default: {DEFAULT_STATE})")
    parser.add_argument("--go", action="store_true", help="create and fire, instead of previewing")
    parser.add_argument("--limit", type=int, help="restore only the first N workspaces")
    parser.add_argument("--skip", default="", help="comma-separated slots to leave out entirely")
    parser.add_argument("--no-commands", action="store_true",
                        help="leave dev-server `command` panes alone; viewers still re-run")
    parser.add_argument("--delay", type=float, default=0.4,
                        help="seconds between agent launches (default: 0.4)")
    args = parser.parse_args()

    skip = {int(s) for s in args.skip.split(",") if s.strip()}
    state = load_state(args.state)
    workspaces = select(state, args.limit, skip)
    live, agents, tabs_live = live_state()

    adopted, paired = {}, {}
    for workspace in workspaces:
        cwd = expand(leaves(workspace["tabs"][0]["layout"])[0]["cwd"])
        workspace_id = live.get((workspace["label"], cwd))
        adopted[workspace["workspace_id"]] = workspace_id
        if workspace_id:
            paired.update(pair_tabs(workspace["tabs"], tabs_live.get(workspace_id, [])))

    tabs = [tab for workspace in workspaces for tab in workspace["tabs"]]
    targets = [(leaf, paired.get(tab["tab_id"], (None, {}))[1].get(leaf["pane_id"]))
               for tab in tabs for leaf in leaves(tab["layout"])]
    running = [leaf for leaf, pane in targets if already_running(leaf, pane, agents)]
    firing = [leaf for leaf, pane in targets
              if will_fire(leaf, args.no_commands) and not already_running(leaf, pane, agents)]
    mode = "FIRING" if args.go else "DRY-RUN (pass --go to fire)"
    print(f"{mode}: {len(workspaces)} workspaces, {len(tabs)} tabs, "
          f"{len(firing)} panes to fire, {len(running)} already running, "
          f"{len(targets) - len(firing) - len(running)} not fired\n")

    restorer = Restorer(args, agents, paired)
    restored = {}
    for workspace in workspaces:
        restored[workspace["workspace_id"]] = restorer.build_workspace(
            workspace, adopted[workspace["workspace_id"]])
    restore_focus(state, restored, args.go)

    if args.go:
        print(f"\nFired {restorer.fired} of {len(firing)} panes; "
              f"{restorer.running} already running; {restorer.skipped} skipped.")
    else:
        print("\nNothing sent. Re-run with --go to restore these workspaces.")


if __name__ == "__main__":
    main()
