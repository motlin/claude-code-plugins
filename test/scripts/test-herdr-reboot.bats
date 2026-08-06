#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPTS_DIR="$PROJECT_ROOT/plugins/herdr-reboot/scripts"
    PLUGIN_DIR="$PROJECT_ROOT/plugins/herdr-reboot"
    FAKE_HOME="$BATS_TEST_TMPDIR/home"
    FIXTURES="$BATS_TEST_TMPDIR/fixtures"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    HERDR_LOG="$BATS_TEST_TMPDIR/herdr.log"
    STATE="$BATS_TEST_TMPDIR/state.json"
    mkdir -p "$FAKE_HOME" "$FIXTURES" "$STUB_BIN"
    # `python3` on PATH may be a mise shim, which refuses to run at all once HOME is faked
    # (it loses its config trust store). Resolve the real interpreter while HOME is still real.
    PYTHON3="$(python3 -c 'import sys; print(sys.executable)')"
    : >"$HERDR_LOG"
    write_herdr_stub
}

# A fake `herdr` that logs every invocation, answers reads from $FIXTURES, and models the
# two behaviours that broke the hand-rolled restore: `pane run` succeeds with no output, and
# a freshly created tab is an idle shell.
write_herdr_stub() {
    cat >"$STUB_BIN/herdr" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$HERDR_LOG"
next_id() {
    local n
    n=$(($(cat "$HERDR_FIXTURES/counter" 2>/dev/null || echo 0) + 1))
    printf '%s\n' "$n" >"$HERDR_FIXTURES/counter"
    printf '%s\n' "$n"
}
case "$1 $2" in
    "api snapshot")
        cat "$HERDR_FIXTURES/snapshot.json"
        ;;
    "session list")
        printf '%s\n' 'name status directory socket' 'testsession running /tmp /tmp/herdr.sock'
        ;;
    "pane process-info")
        pane="$3"
        [ "$pane" = "--pane" ] && pane="$4"
        fixture="$HERDR_FIXTURES/process-${pane//:/_}.json"
        if [ -f "$fixture" ]; then
            cat "$fixture"
        else
            cat "$HERDR_FIXTURES/process-default.json"
        fi
        ;;
    "workspace create")
        n=$(next_id)
        printf '{"id":"cli","result":{"type":"workspace_created","workspace":{"workspace_id":"n%s"},"tab":{"tab_id":"n%s:t1"},"root_pane":{"pane_id":"n%s:p1"}}}\n' "$n" "$n" "$n"
        ;;
    "tab create")
        n=$(next_id)
        printf '{"id":"cli","result":{"type":"tab_created","tab":{"tab_id":"n%s:t1"},"root_pane":{"pane_id":"n%s:p1"}}}\n' "$n" "$n"
        ;;
    "pane run") exit 0 ;;
    "workspace focus") exit 0 ;;
    *)
        printf 'stub herdr: unhandled %s\n' "$*" >&2
        exit 2
        ;;
esac
STUB
    chmod +x "$STUB_BIN/herdr"
    process_fixture default idle
}

# Each spec is `workspace_id,label,tab_number,cwd,agent,session_id`; agent and session_id
# may be empty. Workspace order follows first appearance.
write_snapshot() {
    "$PYTHON3" - "$@" >"$FIXTURES/snapshot.json" <<'PY'
import json, sys

workspaces, tabs, panes = [], [], []
for spec in sys.argv[1:]:
    wsid, label, tabno, cwd, agent, session = spec.split(",")
    if wsid not in [w["workspace_id"] for w in workspaces]:
        workspaces.append({
            "workspace_id": wsid,
            "label": label,
            "number": len(workspaces) + 1,
            "focused": False,
        })
    tabs.append({
        "tab_id": f"{wsid}:t{tabno}",
        "workspace_id": wsid,
        "label": label,
        "number": int(tabno),
    })
    pane = {
        "pane_id": f"{wsid}:p{tabno}",
        "tab_id": f"{wsid}:t{tabno}",
        "workspace_id": wsid,
        "cwd": cwd,
        "agent": agent or None,
    }
    if session:
        pane["agent_session"] = {"agent": agent, "kind": "id", "value": session}
    panes.append(pane)

print(json.dumps({"id": "cli:api:snapshot", "result": {"snapshot": {
    "focused_workspace_id": workspaces[0]["workspace_id"] if workspaces else None,
    "workspaces": workspaces,
    "tabs": tabs,
    "panes": panes,
}}}))
PY
}

# process_fixture <pane_id|default> <idle|command|claude|codex> [cmdline]
process_fixture() {
    local pane="$1" mode="$2" cmdline="${3:-}"
    "$PYTHON3" - "$mode" "$cmdline" >"$FIXTURES/process-${pane//:/_}.json" <<'PY'
import json, sys

mode, cmdline = sys.argv[1], sys.argv[2]
if mode == "idle":
    leader = {"argv": ["-zsh"], "argv0": "zsh", "cmdline": "-zsh", "name": "zsh", "pid": 100}
    shell_pid = 100
else:
    argv = cmdline.split()
    leader = {"argv": argv, "argv0": argv[0], "cmdline": cmdline, "name": argv[0], "pid": 200}
    shell_pid = 100
print(json.dumps({"id": "cli", "result": {"type": "pane_process_info", "process_info": {
    "foreground_process_group_id": leader["pid"],
    "shell_pid": shell_pid,
    "foreground_processes": [leader],
}}}))
PY
}

run_snapshot() {
    run env HOME="$FAKE_HOME" PATH="$STUB_BIN:$PATH" \
        HERDR_LOG="$HERDR_LOG" HERDR_FIXTURES="$FIXTURES" \
        "$PYTHON3" "$SCRIPTS_DIR/snapshot.py" "$@"
}

run_restore() {
    run env HOME="$FAKE_HOME" PATH="$STUB_BIN:$PATH" \
        HERDR_LOG="$HERDR_LOG" HERDR_FIXTURES="$FIXTURES" \
        "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$@" --delay 0
}

# Reads a jq-ish path out of the snapshot JSON on stdout of the last `run`.
json_field() {
    printf '%s' "$output" | "$PYTHON3" -c "
import json, sys
data = json.loads(sys.stdin.read())
print(eval('data' + sys.argv[1]))
" "$1"
}

write_state() {
    "$PYTHON3" - "$@" >"$STATE" <<'PY'
import json, sys

rows = []
for slot, spec in enumerate(sys.argv[1:], 1):
    name, tool, command, cwd, session = spec.split(",")
    rows.append({
        "slot": slot,
        "name": name,
        "tool": tool,
        "command": command or None,
        "cwd": cwd,
        "session_id": session or None,
        "note": "",
    })
print(json.dumps({
    "schema": "resume-after-reboot/v1",
    "captured": "2026-07-29T20:22:47-04:00",
    "backend": "herdr",
    "session": "testsession",
    "rows": rows,
}))
PY
}

codex_rollout() {
    local cwd="$1" uuid="$2"
    local dir="$FAKE_HOME/.codex/sessions/2026/07/29"
    mkdir -p "$dir"
    printf '{"payload":{"cwd":"%s"}}\n' "$cwd" >"$dir/rollout-2026-07-29T10-00-00-$uuid.jsonl"
}

@test "snapshot writes the shared v1 schema envelope" {
    write_snapshot "w6,toolkit,1,$FAKE_HOME/work/toolkit,,"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['schema']")" = "resume-after-reboot/v1" ]
    [ "$(json_field "['backend']")" = "herdr" ]
    [ "$(json_field "['session']")" = "testsession" ]
    [ "$(json_field "['captured'][4]")" = "-" ]
}

@test "snapshot takes a claude pane's session id straight from herdr" {
    write_snapshot "w8,webapp,1,$FAKE_HOME/projects/webapp,claude,3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['slot']")" = "1" ]
    [ "$(json_field "['rows'][0]['name']")" = "webapp" ]
    [ "$(json_field "['rows'][0]['tool']")" = "claude" ]
    [ "$(json_field "['rows'][0]['command']")" = "claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" ]
    [ "$(json_field "['rows'][0]['session_id']")" = "3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" ]
    tilde_home="~"
    [ "$(json_field "['rows'][0]['cwd']")" = "$tilde_home/projects/webapp" ]
}

@test "snapshot takes a codex pane's session id straight from herdr when it reports one" {
    write_snapshot "w6,toolkit,4,$FAKE_HOME/work/toolkit,codex,019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['tool']")" = "codex" ]
    [ "$(json_field "['rows'][0]['command']")" = "codex resume 019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718" ]
    [ "$(json_field "['rows'][0]['session_id']")" = "019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718" ]
}

@test "snapshot falls back to the rollout index for a codex pane with no reported session" {
    codex_rollout "$FAKE_HOME/projects/dashboard" "019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718"
    write_snapshot "wP,dashboard,1,$FAKE_HOME/projects/dashboard,codex,"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['tool']")" = "codex" ]
    [ "$(json_field "['rows'][0]['command']")" = "codex resume 019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718" ]
    [ "$(json_field "['rows'][0]['session_id']")" = "019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718" ]
    [[ "$(json_field "['rows'][0]['note']")" == *rollout* ]]
}

@test "snapshot records codex resume --last with a null session id when no rollout matches" {
    write_snapshot "wN,notes,1,$FAKE_HOME/projects/notes,codex,"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['command']")" = "codex resume --last" ]
    [ "$(json_field "['rows'][0]['session_id']")" = "None" ]
}

@test "snapshot pairs multiple codex panes in one cwd newest-rollout-first" {
    codex_rollout "$FAKE_HOME/projects/dashboard" "019b2c3d-4e5f-7061-b2c3-d4e5f6071829"
    sleep 1
    codex_rollout "$FAKE_HOME/projects/dashboard" "019c3d4e-5f60-7172-c3d4-e5f607182930"
    write_snapshot \
        "wA,dashboard,1,$FAKE_HOME/projects/dashboard,codex," \
        "wA,dashboard,2,$FAKE_HOME/projects/dashboard,codex,"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['session_id']")" = "019c3d4e-5f60-7172-c3d4-e5f607182930" ]
    [ "$(json_field "['rows'][1]['session_id']")" = "019b2c3d-4e5f-7061-b2c3-d4e5f6071829" ]
}

@test "snapshot records an agentless pane at an idle shell as a shell row" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['tool']")" = "shell" ]
    [ "$(json_field "['rows'][0]['command']")" = "None" ]
    [ "$(json_field "['rows'][0]['session_id']")" = "None" ]
}

@test "snapshot records an allowlisted foreground command as a command row" {
    write_snapshot "w8,webapp,3,$FAKE_HOME/projects/webapp,,"
    process_fixture "w8:p3" command "just dev"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['tool']")" = "command" ]
    [ "$(json_field "['rows'][0]['command']")" = "just dev" ]
    [ "$(json_field "['rows'][0]['session_id']")" = "None" ]
}

@test "snapshot treats an unallowlisted foreground program as a shell row" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    process_fixture "wS:p1" command "vim notes.md"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['tool']")" = "shell" ]
}

@test "snapshot numbers slots by workspace order then tab order" {
    write_snapshot \
        "wB,second,2,$FAKE_HOME/b,," \
        "w6,first,3,$FAKE_HOME/a,," \
        "w6,first,1,$FAKE_HOME/a,," \
        "wB,second,1,$FAKE_HOME/b,,"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['rows'][0]['name']")" = "second" ]
    [ "$(json_field "['rows'][0]['slot']")" = "1" ]
    [ "$(json_field "['rows'][1]['name']")" = "second" ]
    [ "$(json_field "['rows'][2]['name']")" = "first" ]
    [ "$(json_field "['rows'][3]['name']")" = "first" ]
    [ "$(json_field "['rows'][3]['slot']")" = "4" ]
}

@test "snapshot --output writes the state file instead of stdout" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"

    run_snapshot --output "$STATE"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run "$PYTHON3" -c "import json,sys; print(json.load(open(sys.argv[1]))['schema'])" "$STATE"
    [ "$output" = "resume-after-reboot/v1" ]
}

@test "restore rejects a state file whose schema is not resume-after-reboot/v1" {
    printf '{"schema":"resume-after-reboot/v2","backend":"herdr","rows":[]}\n' >"$STATE"

    run_restore "$STATE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"resume-after-reboot/v1"* ]]
}

@test "restore accepts a state file captured by the tmux backend" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    "$PYTHON3" - "$STATE" <<'PY'
import json, sys
json.dump({"schema": "resume-after-reboot/v1", "captured": "2026-07-29T20:22:47-04:00",
           "backend": "tmux", "session": "main", "rows": []}, open(sys.argv[1], "w"))
PY

    run_restore "$STATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 workspaces"* ]]
}

@test "restore dry run reports the plan and touches nothing" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state \
        "webapp,claude,claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607,~/projects/webapp,3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" \
        "webapp,shell,,~/projects/webapp," \
        "api-server,claude,claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f,~/projects/api-server,7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"

    run_restore "$STATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
    [[ "$output" == *"2 workspaces"* ]]
    [[ "$output" == *"3 tabs"* ]]

    run grep -c -e "workspace create" -e "tab create" -e "pane run" "$HERDR_LOG"
    [ "$output" = "0" ]
}

@test "restore --go creates one workspace per cwd and one tab per row" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state \
        "webapp,claude,claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607,~/projects/webapp,3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" \
        "webapp,shell,,~/projects/webapp," \
        "api-server,claude,claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f,~/projects/api-server,7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -c "workspace create" "$HERDR_LOG"
    [ "$output" = "2" ]

    run grep -c "tab create" "$HERDR_LOG"
    [ "$output" = "1" ]

    run grep -F -- "workspace create --cwd $FAKE_HOME/projects/webapp --label webapp --no-focus" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore --go fires each agent row into its own pane and reports success" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state \
        "api-server,claude,claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f,~/projects/api-server,7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f" \
        "api-server,codex,codex resume 019b2c3d-4e5f-7061-b2c3-d4e5f6071829,~/projects/api-server,019b2c3d-4e5f-7061-b2c3-d4e5f6071829"

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"FIRING"* ]]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "2" ]

    run grep -F -- "pane run n1:p1 claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore --go creates a tab for a shell row but fires no command into it" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state "api-server,shell,,~/projects/api-server,"

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -c "workspace create" "$HERDR_LOG"
    [ "$output" = "1" ]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "0" ]
}

@test "restore skips command rows by default and says why" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state "webapp,command,just dev,~/projects/webapp,"

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    [[ "$output" == *"--commands"* ]]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "0" ]

    run grep -c -e "tab create" -e "workspace create" "$HERDR_LOG"
    [ "$output" = "1" ]
}

@test "restore --commands fires command rows" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state "webapp,command,just dev,~/projects/webapp,"

    run_restore "$STATE" --go --commands
    [ "$status" -eq 0 ]

    run grep -F -- "pane run n1:p1 just dev" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore adopts an existing workspace with the same cwd and gives every row a fresh tab" {
    write_snapshot "w8,webapp,1,$FAKE_HOME/projects/webapp,claude,3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"
    write_state \
        "webapp,claude,claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607,~/projects/webapp,3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" \
        "webapp,shell,,~/projects/webapp,"

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"adopt w8"* ]]

    run grep -c "workspace create" "$HERDR_LOG"
    [ "$output" = "0" ]

    run grep -c "tab create" "$HERDR_LOG"
    [ "$output" = "2" ]

    run grep -F -- "pane run w8:p1" "$HERDR_LOG"
    [ "$status" -ne 0 ]
}

@test "restore refuses to fire into a pane that is not an idle shell" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state "api-server,claude,claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f,~/projects/api-server,7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"
    process_fixture "n1:p1" claude "claude --resume b1c2d3e4-f506-4718-8293-a4b5c6d7e8f9"

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    [[ "$output" == *"claude"* ]]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "0" ]
}

@test "restore --limit keeps only the first N workspaces" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state \
        "webapp,shell,,~/projects/webapp," \
        "api-server,shell,,~/projects/api-server," \
        "notes,shell,,~/projects/notes,"

    run_restore "$STATE" --limit 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 workspaces"* ]]
    [[ "$output" != *notes* ]]
}

@test "restore --skip drops rows by slot" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state \
        "webapp,claude,claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607,~/projects/webapp,3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" \
        "api-server,claude,claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f,~/projects/api-server,7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"

    run_restore "$STATE" --skip 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 workspaces"* ]]
    [[ "$output" != *webapp* ]]
    [[ "$output" == *api-server* ]]
}

@test "restore returns focus to the workspace that had it before the run" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    write_state "api-server,shell,,~/projects/api-server,"

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -F -- "workspace focus wS" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore reads .llm/resume-after-reboot-state.json when given no state file" {
    write_snapshot "wS,toolkit,1,$FAKE_HOME/work/toolkit,,"
    project="$BATS_TEST_TMPDIR/project"
    mkdir -p "$project/.llm"
    STATE="$project/.llm/resume-after-reboot-state.json"
    write_state "api-server,shell,,~/projects/api-server,"

    command cd "$project"
    run_restore
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 workspaces"* ]]
    [[ "$output" == *api-server* ]]
}

@test "herdr-reboot manifests are valid JSON and share the plugin version" {
    run "$PYTHON3" -c "
import json, sys
claude = json.load(open(sys.argv[1] + '/.claude-plugin/plugin.json'))
codex = json.load(open(sys.argv[2] + '/.codex-plugin/plugin.json'))
assert claude['name'] == codex['name'] == 'herdr-reboot', claude['name']
assert claude['version'] == codex['version'], (claude['version'], codex['version'])
assert codex['skills'] == './skills/', codex['skills']
print(claude['version'])
" "$PLUGIN_DIR" "$PLUGIN_DIR"
    [ "$status" -eq 0 ]
    # Shape, not a literal: `just release` bumps every manifest, so pinning the
    # version here fails the suite on release. The claude-to-codex match is
    # asserted above, and marketplace-to-manifest parity in
    # test/hooks/test-plugin-validate.bats.
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "herdr-reboot skills exist with frontmatter naming them" {
    run grep -c "^name: snapshot$" "$PLUGIN_DIR/skills/snapshot/SKILL.md"
    [ "$output" = "1" ]

    run grep -c "^name: restore$" "$PLUGIN_DIR/skills/restore/SKILL.md"
    [ "$output" = "1" ]
}
