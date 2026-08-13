#!/usr/bin/env python3
"""Build herdr-reboot test fixtures from one compact description of a session tree.

A test describes the tree once:

    {"workspaces": [{"id": "wA", "label": "kalshi", "tabs": [
        {"id": "wA:t1", "label": "bot", "layout": {"split": "right", "ratio": 0.6, "children": [
            {"pane": "wA:p1", "cwd": "/w/kalshi", "agent": "claude", "session": "abc"},
            {"pane": "wA:p2", "cwd": "/w/kalshi"}]}}]}]}

and this renders it two ways:

    snapshot  what `herdr api snapshot` would report for that tree, rects and splits included
    state     what snapshot.py would write for it, the `resume-after-reboot/v2` state file

Layout nodes are either a pane leaf or a split with exactly two children. Everything except
`id` has a default: labels, numbers, active tab, focused pane, and focus all follow the first
entry at their level.

Usage:
    herdr_fixture.py snapshot|state <description.json | ->
"""
import json, sys

SCHEMA = "resume-after-reboot/v2"
AREA = {"x": 0, "y": 1, "width": 120, "height": 40}


def leaves(node):
    return [node] if "pane" in node else [leaf for kid in node["children"] for leaf in leaves(kid)]


def halves(node, area):
    """The two child areas a split carves out of its area, the way herdr lays them out."""
    if node["split"] == "right":
        width = round(node["ratio"] * area["width"])
        return ({**area, "width": width},
                {**area, "x": area["x"] + width, "width": area["width"] - width})
    height = round(node["ratio"] * area["height"])
    return ({**area, "height": height},
            {**area, "y": area["y"] + height, "height": area["height"] - height})


def geometry(node, area, panes, splits):
    if "pane" in node:
        panes.append((node, dict(area)))
        return
    splits.append({"direction": node["split"], "id": f"split_{len(splits)}", "rect": dict(area),
                   "ratio": node["ratio"]})
    first, second = halves(node, area)
    geometry(node["children"][0], first, panes, splits)
    geometry(node["children"][1], second, panes, splits)


def walk(doc):
    """(workspace, tab, layout node) for every pane, in workspace then tab then layout order."""
    for workspace in doc["workspaces"]:
        for tab in workspace["tabs"]:
            for leaf in leaves(tab["layout"]):
                yield workspace, tab, leaf


def tab_label(workspace, tab):
    return tab.get("label", workspace.get("label", workspace["id"]))


def focused_pane(tab):
    return tab.get("focused_pane", leaves(tab["layout"])[0]["pane"])


def active_tab(workspace):
    return workspace.get("active_tab", workspace["tabs"][0]["id"])


def focus(doc):
    first_workspace = doc["workspaces"][0]
    first_tab = first_workspace["tabs"][0]
    return {**{"workspace": first_workspace["id"], "tab": first_tab["id"],
               "pane": focused_pane(first_tab)},
            **doc.get("focus", {})}


def snapshot(doc):
    """The live-session JSON `herdr api snapshot` prints for this tree."""
    where = focus(doc)
    workspaces, tabs, panes, layouts = [], [], [], []
    for number, workspace in enumerate(doc["workspaces"], 1):
        workspaces.append({
            "workspace_id": workspace["id"],
            "label": workspace.get("label", workspace["id"]),
            "number": workspace.get("number", number),
            "active_tab_id": active_tab(workspace),
            "focused": workspace["id"] == where["workspace"],
        })
        for tab_number, tab in enumerate(workspace["tabs"], 1):
            laid_out, splits = [], []
            geometry(tab["layout"], AREA, laid_out, splits)
            tabs.append({
                "tab_id": tab["id"],
                "workspace_id": workspace["id"],
                "label": tab_label(workspace, tab),
                "number": tab.get("number", tab_number),
                "pane_count": len(laid_out),
            })
            layouts.append({
                "workspace_id": workspace["id"],
                "tab_id": tab["id"],
                "area": dict(AREA),
                "focused_pane_id": focused_pane(tab),
                "zoomed": tab.get("zoomed", False),
                "panes": [{"pane_id": leaf["pane"], "focused": leaf["pane"] == focused_pane(tab),
                           "rect": rect} for leaf, rect in laid_out],
                "splits": splits,
            })
            for leaf, _ in laid_out:
                pane = {
                    "pane_id": leaf["pane"],
                    "tab_id": tab["id"],
                    "workspace_id": workspace["id"],
                    "cwd": leaf["cwd"],
                    "agent": leaf.get("agent") or None,
                }
                if leaf.get("session"):
                    pane["agent_session"] = {"agent": leaf["agent"], "kind": "id",
                                             "value": leaf["session"]}
                panes.append(pane)
    return {"id": "cli:api:snapshot", "result": {"snapshot": {
        "focused_workspace_id": where["workspace"],
        "focused_tab_id": where["tab"],
        "focused_pane_id": where["pane"],
        "workspaces": workspaces,
        "tabs": tabs,
        "panes": panes,
        "layouts": layouts,
    }}}


def state_layout(node, slots):
    if "split" in node:
        return {"type": "split", "direction": node["split"], "ratio": node["ratio"],
                "children": [state_layout(kid, slots) for kid in node["children"]]}
    built = {
        "type": "pane",
        "slot": slots[node["pane"]],
        "pane_id": node["pane"],
        "tool": node.get("tool", node.get("agent") or "shell"),
        "command": node.get("command"),
        "cwd": node["cwd"],
        "session_id": node.get("session"),
        "note": node.get("note", ""),
    }
    if "restore_default" in node:
        built["restore_default"] = node["restore_default"]
    return built


def state(doc):
    """The `resume-after-reboot/v2` state file snapshot.py writes for this tree."""
    slots = {leaf["pane"]: slot for slot, (_, _, leaf) in enumerate(walk(doc), 1)}
    where = focus(doc)
    return {
        "schema": SCHEMA,
        "captured": "2026-07-29T20:22:47-04:00",
        "backend": "herdr",
        "session": doc.get("session", "testsession"),
        "focus": {"workspace_id": where["workspace"], "tab_id": where["tab"],
                  "pane_id": where["pane"]},
        "workspaces": [{
            "workspace_id": workspace["id"],
            "label": workspace.get("label", workspace["id"]),
            "number": workspace.get("number", number),
            "active_tab_id": active_tab(workspace),
            "tabs": [{
                "tab_id": tab["id"],
                "label": tab_label(workspace, tab),
                "number": tab.get("number", tab_number),
                "zoomed": tab.get("zoomed", False),
                "focused_pane_id": focused_pane(tab),
                "layout": state_layout(tab["layout"], slots),
            } for tab_number, tab in enumerate(workspace["tabs"], 1)],
        } for number, workspace in enumerate(doc["workspaces"], 1)],
    }


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("snapshot", "state"):
        sys.exit(__doc__.rpartition("Usage:")[2].strip())
    source = sys.stdin if sys.argv[2] == "-" else open(sys.argv[2])
    doc = json.load(source)
    print(json.dumps(snapshot(doc) if sys.argv[1] == "snapshot" else state(doc), indent=2))


if __name__ == "__main__":
    main()
