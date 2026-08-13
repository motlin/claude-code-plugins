#!/usr/bin/env bats

CLAUDE_UUID="3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"
CODEX_UUID="019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718"
SCHEMA="resume-after-reboot/v1"

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPTS_DIR="$PROJECT_ROOT/plugins/tmux-reboot/scripts"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    FAKE_HOME="$BATS_TEST_TMPDIR/home"
    STATE="$BATS_TEST_TMPDIR/state.json"
    SPAWNED=()

    mkdir -p "$STUB_BIN" "$FAKE_HOME"
    export TMUX_STUB_PANES_SNAPSHOT="$BATS_TEST_TMPDIR/panes-snapshot"
    export TMUX_STUB_PANES_RESTORE="$BATS_TEST_TMPDIR/panes-restore"
    export TMUX_STUB_SENT="$BATS_TEST_TMPDIR/sent"
    : >"$TMUX_STUB_PANES_SNAPSHOT"
    : >"$TMUX_STUB_PANES_RESTORE"
    : >"$TMUX_STUB_SENT"

    write_tmux_stub
    # Symlinks keep the real binary's code signature while giving ps the argv[0] the
    # scripts look for; a copy of /bin/sleep gets killed on launch.
    ln -s /bin/sleep "$STUB_BIN/claude"
    ln -s /bin/sleep "$STUB_BIN/codex"
    ln -s /bin/sleep "$STUB_BIN/just"

    # `python3` on PATH may be a mise shim, and mise refuses to run once HOME no longer
    # holds its trust store. Resolve the real interpreter while HOME is still intact.
    PYTHON3="$(python3 -c 'import sys; print(sys.executable)')"

    export HOME="$FAKE_HOME"
    export PATH="$STUB_BIN:$PATH"
}

teardown() {
    for pid in "${SPAWNED[@]:-}"; do
        [ -n "$pid" ] || continue
        pkill -P "$pid" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
    done
}

# A tmux that answers from fixture files and logs everything it is asked to send.
write_tmux_stub() {
    cat >"$STUB_BIN/tmux" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    display-message)
        case "$*" in
            *session_name*) printf '%s\n' "${TMUX_STUB_SESSION:-main}" ;;
            *window_index*) printf '%s\n' "${TMUX_STUB_WINDOW:-1}" ;;
        esac
        ;;
    list-panes)
        case "$*" in
            *window_name*) cat "$TMUX_STUB_PANES_SNAPSHOT" ;;
            *) cat "$TMUX_STUB_PANES_RESTORE" ;;
        esac
        ;;
    send-keys) printf '%s\n' "$*" >>"$TMUX_STUB_SENT" ;;
esac
STUB
    chmod +x "$STUB_BIN/tmux"
}

break_tmux_stub() {
    printf '#!/bin/sh\nexit 1\n' >"$STUB_BIN/tmux"
    chmod +x "$STUB_BIN/tmux"
}

snapshot_pane() { # window_index window_name pane_pid cwd
    printf 'main|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" >>"$TMUX_STUB_PANES_SNAPSHOT"
}

restore_pane() { # window_index cwd pane_pid current_command
    printf 'main|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" >>"$TMUX_STUB_PANES_RESTORE"
}

# Run a program under a shell so the shell's pid stands in for a tmux pane pid; the
# trailing `true` keeps bash from exec'ing the program in place of itself.
spawn_pane_shell() { # program -> sets PANE_PID
    # shellcheck disable=SC2016
    bash -c '"$1" 60; true' bash "$1" &
    PANE_PID=$!
    SPAWNED+=("$PANE_PID")
    local waited=0
    until [ -n "$(pgrep -P "$PANE_PID")" ]; do
        sleep 0.05
        waited=$((waited + 1))
        [ "$waited" -lt 100 ] || return 1
    done
}

# Same, but the caller picks the whole argument list rather than getting a bare `60`.
# Classification reads the command line out of ps, so the arguments are the point here.
# Output goes nowhere because a flags-only stub has to be something chatty like `yes`.
spawn_pane_command() { # program [args...] -> sets PANE_PID
    # shellcheck disable=SC2016
    bash -c '"$@" >/dev/null 2>&1; true' bash "$@" &
    PANE_PID=$!
    SPAWNED+=("$PANE_PID")
    local waited=0
    until [ -n "$(pgrep -P "$PANE_PID")" ]; do
        sleep 0.05
        waited=$((waited + 1))
        [ "$waited" -lt 100 ] || return 1
    done
}

# Viewers need argv[0] to be the program the classifier looks for. /bin/sleep suits any
# stub whose arguments end in a number; a flags-only command line needs /usr/bin/yes,
# which outlives the snapshot no matter what it is handed.
link_viewer_stub() { # name [target]
    ln -s "${2:-/bin/sleep}" "$STUB_BIN/$1"
}

# Classify a synthetic process tree: each argument is one process, the first a child of
# the pane and the rest its descendants in order. Spawning these for real is not an option
# -- every long-lived stub on macOS either rejects non-numeric arguments (sleep) or
# rewrites its own argv where ps can see it (yes), and the git cases turn on the exact
# command line.
classify_tree() { # cmdline [descendant_cmdline...]
    "$PYTHON3" - "$SCRIPTS_DIR" "$@" <<'PY'
import sys

sys.path.insert(0, sys.argv[1])
import snapshot

cmdlines = sys.argv[2:]
kids = {100: [200]}
commands = {}
for offset, cmdline in enumerate(cmdlines):
    pid = 200 + offset
    commands[pid] = cmdline
    if offset:
        kids.setdefault(pid - 1, []).append(pid)
print(snapshot.find_command(100, kids, commands))
PY
}

write_claude_transcript() { # cwd uuid mtime_stamp
    local slug="${1//\//-}"
    mkdir -p "$FAKE_HOME/.claude/projects/$slug"
    printf '{}\n' >"$FAKE_HOME/.claude/projects/$slug/$2.jsonl"
    touch -t "$3" "$FAKE_HOME/.claude/projects/$slug/$2.jsonl"
}

write_codex_rollout() { # cwd uuid mtime_stamp
    local dir="$FAKE_HOME/.codex/sessions/2026/07/29"
    mkdir -p "$dir"
    local file="$dir/rollout-2026-07-29T20-22-47-$2.jsonl"
    printf '{"payload":{"cwd":"%s"}}\n' "$1" >"$file"
    touch -t "$3" "$file"
}

assert_json_equals() { # actual_json expected_json
    "$PYTHON3" - "$1" "$2" <<'PY'
import json, sys

actual, expected = (json.loads(argument) for argument in sys.argv[1:3])
if actual != expected:
    print("actual:   " + json.dumps(actual, sort_keys=True))
    print("expected: " + json.dumps(expected, sort_keys=True))
    sys.exit(1)
PY
}

row_json() { # document_json index
    "$PYTHON3" -c 'import json, sys; print(json.dumps(json.loads(sys.argv[1])["rows"][int(sys.argv[2])]))' \
        "$1" "$2"
}

row_field() { # document_json index field
    "$PYTHON3" -c \
        'import json, sys; print(json.loads(sys.argv[1])["rows"][int(sys.argv[2])].get(sys.argv[3]))' \
        "$1" "$2" "$3"
}

envelope_json() { # document_json -- the document minus its rows and capture time
    "$PYTHON3" -c '
import json, sys
document = json.loads(sys.argv[1])
document.pop("rows")
document.pop("captured")
print(json.dumps(document))' "$1"
}

write_state() { # rows_json -- a hand-written v1 state file, backend recorded as "other"
    cat >"$STATE" <<EOF
{
  "schema": "$SCHEMA",
  "captured": "2026-07-29T20:22:47-04:00",
  "backend": "other",
  "session": "main",
  "rows": $1
}
EOF
}

@test "snapshot emits the resume-after-reboot/v1 envelope" {
    export TMUX_STUB_SESSION="work"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]

    assert_json_equals "$(envelope_json "$output")" \
        '{"schema": "resume-after-reboot/v1", "backend": "tmux", "session": "work"}'
    assert_json_equals "$(row_json "$output" 0 || echo '[]')" '[]'
}

@test "snapshot stamps captured as an ISO 8601 time with an offset" {
    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]

    run "$PYTHON3" -c '
import datetime, json, sys
captured = json.loads(sys.argv[1])["captured"]
print(datetime.datetime.fromisoformat(captured).utcoffset() is not None)' "$output"
    [ "$output" = "True" ]
}

@test "snapshot breaks the claude session id out of the resume command" {
    write_claude_transcript "$FAKE_HOME/projects/webapp" "$CLAUDE_UUID" 202607292017
    spawn_pane_shell "$STUB_BIN/claude"
    snapshot_pane 1 webapp "$PANE_PID" "$FAKE_HOME/projects/webapp"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]

    assert_json_equals "$(row_json "$output" 0)" '{
        "slot": 1,
        "name": "webapp",
        "tool": "claude",
        "command": "claude --resume '"$CLAUDE_UUID"'",
        "cwd": "~/projects/webapp",
        "session_id": "'"$CLAUDE_UUID"'",
        "note": "session mtime 2026-07-29 20:17"
    }'
}

@test "snapshot breaks the codex session id out of the resume command" {
    write_codex_rollout "$FAKE_HOME/projects/api-server" "$CODEX_UUID" 202607292022
    spawn_pane_shell "$STUB_BIN/codex"
    snapshot_pane 6 api-server "$PANE_PID" "$FAKE_HOME/projects/api-server"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]

    assert_json_equals "$(row_json "$output" 0)" '{
        "slot": 1,
        "name": "api-server",
        "tool": "codex",
        "command": "codex resume '"$CODEX_UUID"'",
        "cwd": "~/projects/api-server",
        "session_id": "'"$CODEX_UUID"'",
        "note": "rollout mtime 2026-07-29 20:22"
    }'
}

@test "snapshot records an idle pane as a shell row with no command" {
    spawn_pane_shell /bin/sleep
    snapshot_pane 3 dashboard "$PANE_PID" "$FAKE_HOME/projects/dashboard"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]

    assert_json_equals "$(row_json "$output" 0)" '{
        "slot": 1,
        "name": "dashboard",
        "tool": "shell",
        "command": null,
        "cwd": "~/projects/dashboard",
        "session_id": null,
        "note": ""
    }'
}

@test "snapshot records a long-running foreground command with no session id" {
    spawn_pane_shell "$STUB_BIN/just"
    snapshot_pane 29 webapp "$PANE_PID" "$FAKE_HOME/projects/webapp"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]

    assert_json_equals "$(row_json "$output" 0)" '{
        "slot": 1,
        "name": "webapp",
        "tool": "command",
        "command": "'"$STUB_BIN"'/just 60",
        "cwd": "~/projects/webapp",
        "session_id": null,
        "note": "best-effort; re-runs command",
        "restore_default": false
    }'
}

@test "snapshot records a read-only git command as a restorable viewer" {
    run classify_tree "/usr/bin/git log --graph"
    [ "$status" -eq 0 ]
    [ "$output" = "('/usr/bin/git log --graph', True)" ]
}

@test "snapshot treats a mutating git command as a shell row" {
    run classify_tree "/usr/bin/git push origin main"
    [ "$status" -eq 0 ]
    [ "$output" = "None" ]
}

@test "snapshot resolves a git alias before judging it safe" {
    # git resolves an alias by re-execing itself out of git-core, so the expansion is the
    # only honest signal -- the alias name says nothing about what it does.
    run classify_tree "git la" "/usr/libexec/git-core/git log --graph"
    [ "$status" -eq 0 ]
    [ "$output" = "('git la', True)" ]

    run classify_tree "git ra" "/usr/libexec/git-core/git rebase --interactive main"
    [ "$status" -eq 0 ]
    [ "$output" = "None" ]
}

@test "snapshot records a pager holding a file" {
    link_viewer_stub less /usr/bin/yes
    spawn_pane_command "$STUB_BIN/less" CHANGELOG.md
    snapshot_pane 33 notes "$PANE_PID" "$FAKE_HOME/notes"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]
    [ "$(row_field "$output" 0 tool)" = "command" ]
    [ "$(row_field "$output" 0 restore_default)" = "True" ]
}

@test "snapshot treats a pager with no file operand as a shell row" {
    # A bare pager is draining a pipe whose writer dies with the reboot; re-running it
    # would hang the pane on stdin.
    link_viewer_stub less /usr/bin/yes
    spawn_pane_command "$STUB_BIN/less" --RAW-CONTROL-CHARS
    snapshot_pane 34 notes "$PANE_PID" "$FAKE_HOME/notes"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]
    [ "$(row_field "$output" 0 tool)" = "shell" ]
}

@test "snapshot records a system monitor as a restorable viewer" {
    link_viewer_stub htop
    spawn_pane_command "$STUB_BIN/htop" 60
    snapshot_pane 35 dotfiles "$PANE_PID" "$FAKE_HOME/.dotfiles"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]
    [ "$(row_field "$output" 0 tool)" = "command" ]
    [ "$(row_field "$output" 0 restore_default)" = "True" ]
}

@test "snapshot falls back to --continue with a null session id" {
    spawn_pane_shell "$STUB_BIN/claude"
    snapshot_pane 9 notes "$PANE_PID" "$FAKE_HOME/projects/notes"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]

    assert_json_equals "$(row_json "$output" 0)" '{
        "slot": 1,
        "name": "notes",
        "tool": "claude",
        "command": "claude --continue",
        "cwd": "~/projects/notes",
        "session_id": null,
        "note": "no transcript; --continue picks newest in cwd"
    }'
}

@test "snapshot numbers slots 1-based in pane order, not by window index" {
    spawn_pane_shell /bin/sleep
    snapshot_pane 4 first "$PANE_PID" "$FAKE_HOME/projects/first"
    spawn_pane_shell /bin/sleep
    snapshot_pane 7 second "$PANE_PID" "$FAKE_HOME/projects/second"
    spawn_pane_shell /bin/sleep
    snapshot_pane 9 third "$PANE_PID" "$FAKE_HOME/projects/third"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py"
    [ "$status" -eq 0 ]

    run "$PYTHON3" -c '
import json, sys
rows = json.loads(sys.argv[1])["rows"]
print(json.dumps([(row["slot"], row["name"]) for row in rows]))' "$output"
    assert_json_equals "$output" '[[1, "first"], [2, "second"], [3, "third"]]'
}

@test "snapshot snapshots only the requested session" {
    spawn_pane_shell /bin/sleep
    snapshot_pane 1 mine "$PANE_PID" "$FAKE_HOME/projects/mine"
    printf 'other|2|theirs|%s|%s\n' "$PANE_PID" "$FAKE_HOME/projects/theirs" \
        >>"$TMUX_STUB_PANES_SNAPSHOT"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py" main
    [ "$status" -eq 0 ]

    run "$PYTHON3" -c '
import json, sys
print(json.dumps([row["name"] for row in json.loads(sys.argv[1])["rows"]]))' "$output"
    assert_json_equals "$output" '["mine"]'
}

@test "snapshot --output writes the document instead of printing it" {
    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py" --output "$STATE"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]

    run cat "$STATE"
    assert_json_equals "$(envelope_json "$output")" \
        '{"schema": "resume-after-reboot/v1", "backend": "tmux", "session": "main"}'
}

@test "snapshot --help documents the JSON state file" {
    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--output"* ]]
    [[ "$output" == *"resume-after-reboot-state.json"* ]]
}

@test "restore --help documents the JSON state file" {
    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--go"* ]]
    [[ "$output" == *"resume-after-reboot-state.json"* ]]
}

@test "restore defaults to the JSON state file path" {
    run bash -c 'command cd "$1" && "$2" "$3"' bash "$BATS_TEST_TMPDIR" "$PYTHON3" \
        "$SCRIPTS_DIR/restore.py"

    [ "$status" -ne 0 ]
    [ "$output" = "state file not found: .llm/resume-after-reboot-state.json" ]
}

@test "restore rejects a state file written to a different schema" {
    printf '{"schema": "resume-after-reboot/v2", "rows": []}\n' >"$STATE"

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"resume-after-reboot/v1"* ]]
    [[ "$output" == *"resume-after-reboot/v2"* ]]
}

@test "restore rejects a state file with no schema at all" {
    printf '{"rows": []}\n' >"$STATE"

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"resume-after-reboot/v1"* ]]
}

@test "restore rejects a state file that is not JSON" {
    printf '| Win | Name |\n' >"$STATE"

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"$STATE"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "restore plans a state file from another backend against live tmux windows" {
    write_state '[{
        "slot": 1,
        "name": "webapp",
        "tool": "claude",
        "command": "claude --resume '"$CLAUDE_UUID"'",
        "cwd": "~/projects/webapp",
        "session_id": "'"$CLAUDE_UUID"'",
        "note": "session mtime 2026-07-29 20:17"
    }]'
    spawn_pane_shell /bin/sleep
    restore_pane 3 "$FAKE_HOME/projects/webapp" "$PANE_PID" bash

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 matched, 0 skipped"* ]]
    [[ "$output" == *"backend other"* ]]
    [[ "$output" == *"main:3"* ]]
    [[ "$output" == *"claude --resume $CLAUDE_UUID"* ]]
    [[ "$output" == *"@~/projects/webapp"* ]]
    [ ! -s "$TMUX_STUB_SENT" ]
}

@test "restore pairs by cwd rather than by slot" {
    write_state '[{
        "slot": 1,
        "name": "api-server",
        "tool": "codex",
        "command": "codex resume '"$CODEX_UUID"'",
        "cwd": "~/projects/api-server",
        "session_id": "'"$CODEX_UUID"'",
        "note": "rollout mtime 2026-07-29 20:22"
    }]'
    spawn_pane_shell /bin/sleep
    restore_pane 1 "$FAKE_HOME/projects/elsewhere" "$PANE_PID" bash
    spawn_pane_shell /bin/sleep
    restore_pane 12 "$FAKE_HOME/projects/api-server" "$PANE_PID" bash

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 matched, 0 skipped"* ]]
    [[ "$output" == *"main:12"* ]]
}

@test "restore leaves shell rows alone" {
    write_state '[{
        "slot": 1,
        "name": "dashboard",
        "tool": "shell",
        "command": null,
        "cwd": "~/projects/dashboard",
        "session_id": null,
        "note": ""
    }]'
    spawn_pane_shell /bin/sleep
    restore_pane 3 "$FAKE_HOME/projects/dashboard" "$PANE_PID" bash

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 matched, 0 skipped"* ]]
    [[ "$output" != *"dashboard"* ]]
    [ ! -s "$TMUX_STUB_SENT" ]
}

@test "restore --go sends each command with a trailing Enter" {
    write_state '[{
        "slot": 1,
        "name": "webapp",
        "tool": "claude",
        "command": "claude --resume '"$CLAUDE_UUID"'",
        "cwd": "~/projects/webapp",
        "session_id": "'"$CLAUDE_UUID"'",
        "note": ""
    }]'
    spawn_pane_shell /bin/sleep
    restore_pane 3 "$FAKE_HOME/projects/webapp" "$PANE_PID" bash

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"FIRING"* ]]

    run cat "$TMUX_STUB_SENT"
    [ "$output" = "send-keys -t main:3 claude --resume $CLAUDE_UUID Enter" ]
}

@test "restore --skip omits a row by slot" {
    write_state '[{
        "slot": 1,
        "name": "webapp",
        "tool": "claude",
        "command": "claude --continue",
        "cwd": "~/projects/webapp",
        "session_id": null,
        "note": ""
    }, {
        "slot": 2,
        "name": "api-server",
        "tool": "codex",
        "command": "codex resume --last",
        "cwd": "~/projects/api-server",
        "session_id": null,
        "note": ""
    }]'
    spawn_pane_shell /bin/sleep
    restore_pane 3 "$FAKE_HOME/projects/webapp" "$PANE_PID" bash
    spawn_pane_shell /bin/sleep
    restore_pane 4 "$FAKE_HOME/projects/api-server" "$PANE_PID" bash

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE" --skip 1 --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 matched, 1 skipped"* ]]

    run cat "$TMUX_STUB_SENT"
    [ "$output" = "send-keys -t main:4 codex resume --last Enter" ]
}

@test "restore never types into a window that already holds a live agent" {
    write_state '[{
        "slot": 1,
        "name": "webapp",
        "tool": "claude",
        "command": "claude --resume '"$CLAUDE_UUID"'",
        "cwd": "~/projects/webapp",
        "session_id": "'"$CLAUDE_UUID"'",
        "note": ""
    }]'
    spawn_pane_shell "$STUB_BIN/claude"
    restore_pane 3 "$FAKE_HOME/projects/webapp" "$PANE_PID" bash

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 matched, 1 skipped"* ]]
    [[ "$output" == *"already has a live agent"* ]]
    [ ! -s "$TMUX_STUB_SENT" ]
}

@test "restore never types into a window that is not idle at a shell prompt" {
    write_state '[{
        "slot": 1,
        "name": "webapp",
        "tool": "claude",
        "command": "claude --resume '"$CLAUDE_UUID"'",
        "cwd": "~/projects/webapp",
        "session_id": "'"$CLAUDE_UUID"'",
        "note": ""
    }]'
    spawn_pane_shell /bin/sleep
    restore_pane 3 "$FAKE_HOME/projects/webapp" "$PANE_PID" vim

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 matched, 1 skipped"* ]]
    [[ "$output" == *"is running vim, not idle"* ]]
    [ ! -s "$TMUX_STUB_SENT" ]
}

@test "restore says so plainly when no tmux windows are live" {
    write_state '[{
        "slot": 1,
        "name": "webapp",
        "tool": "claude",
        "command": "claude --resume '"$CLAUDE_UUID"'",
        "cwd": "~/projects/webapp",
        "session_id": "'"$CLAUDE_UUID"'",
        "note": ""
    }]'
    break_tmux_stub

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no live tmux windows"* ]]
    [[ "$output" != *"Traceback"* ]]
    [ ! -s "$TMUX_STUB_SENT" ]
}

@test "a snapshot round-trips through restore" {
    write_claude_transcript "$FAKE_HOME/projects/webapp" "$CLAUDE_UUID" 202607292017
    spawn_pane_shell "$STUB_BIN/claude"
    snapshot_pane 1 webapp "$PANE_PID" "$FAKE_HOME/projects/webapp"

    run "$PYTHON3" "$SCRIPTS_DIR/snapshot.py" --output "$STATE"
    [ "$status" -eq 0 ]

    spawn_pane_shell /bin/sleep
    restore_pane 5 "$FAKE_HOME/projects/webapp" "$PANE_PID" bash

    run "$PYTHON3" "$SCRIPTS_DIR/restore.py" "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 matched, 0 skipped"* ]]
    [[ "$output" == *"backend tmux"* ]]

    run cat "$TMUX_STUB_SENT"
    [ "$output" = "send-keys -t main:5 claude --resume $CLAUDE_UUID Enter" ]
}
