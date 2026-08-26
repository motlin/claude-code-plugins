#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPTS_DIR="$PROJECT_ROOT/plugins/herdr-reboot/scripts"
    PLUGIN_DIR="$PROJECT_ROOT/plugins/herdr-reboot"
    FIXTURE="$PROJECT_ROOT/test/lib/herdr_fixture.py"
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
# a freshly created tab is an idle shell. Created ids are workspace-qualified the way herdr's
# are, so a test can tell which workspace a tab or split landed in.
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
option() {
    local want="$1"
    shift
    while [ $# -gt 0 ]; do
        [ "$1" = "$want" ] && { printf '%s\n' "$2"; return; }
        shift
    done
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
        ws=$(option --workspace "$@")
        printf '{"id":"cli","result":{"type":"tab_created","tab":{"tab_id":"%s:t%s"},"root_pane":{"pane_id":"%s:p%s"}}}\n' "$ws" "$n" "$ws" "$n"
        ;;
    "pane split")
        n=$(next_id)
        target=$(option --pane "$@")
        printf '{"id":"cli","result":{"type":"pane_split","pane":{"pane_id":"%s:s%s"}}}\n' "${target%%:*}" "$n"
        ;;
    "pane run") exit 0 ;;
    "pane zoom") exit 0 ;;
    "tab rename") exit 0 ;;
    "tab focus") exit 0 ;;
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

# Both fixtures come from one description of the session tree; see test/lib/herdr_fixture.py.
write_snapshot() {
    printf '%s' "$1" | "$PYTHON3" "$FIXTURE" snapshot - >"$FIXTURES/snapshot.json"
}

write_state() {
    printf '%s' "$1" | "$PYTHON3" "$FIXTURE" state - >"$STATE"
}

# one_pane <workspace_id> <label> <cwd> [agent] [session] — the single-pane tree most tests want.
one_pane() {
    printf '{"workspaces":[{"id":"%s","label":"%s","tabs":[{"id":"%s:t1","layout":
        {"pane":"%s:p1","cwd":"%s","agent":"%s","session":"%s"}}]}]}' \
        "$1" "$2" "$1" "$1" "$3" "${4:-}" "${5:-}"
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

# process_chain_fixture <pane_id> <outermost cmdline> [inner cmdline...]
#
# What a real `git la` pane looks like: git re-execs itself to resolve the alias and pipes
# through a pager, so several foreground processes are live at once. herdr reports them
# newest-pid-first, which is innermost-first, and the process group leader is the outermost
# process -- the command the user actually typed.
process_chain_fixture() {
    local pane="$1"
    shift
    "$PYTHON3" - "$@" >"$FIXTURES/process-${pane//:/_}.json" <<'PY'
import json, sys

processes = []
for offset, cmdline in enumerate(sys.argv[1:]):
    argv = cmdline.split()
    processes.append({"argv": argv, "argv0": argv[0], "cmdline": cmdline,
                      "name": argv[0].split("/")[-1], "pid": 200 + offset})
print(json.dumps({"id": "cli", "result": {"type": "pane_process_info", "process_info": {
    "foreground_process_group_id": processes[0]["pid"],
    "shell_pid": 100,
    "foreground_processes": list(reversed(processes)),
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

# Reads a python path out of the state document on stdout of the last `run`.
json_field() {
    printf '%s' "$output" | "$PYTHON3" -c "
import json, sys
data = json.loads(sys.stdin.read())
print(eval('data' + sys.argv[1]))
" "$1"
}

# pane_field <slot> <key> — a pane leaf out of the state document, found by slot.
pane_field() {
    printf '%s' "$output" | "$PYTHON3" -c '
import json, sys

def leaves(node):
    return [node] if node["type"] == "pane" else [l for c in node["children"] for l in leaves(c)]

doc = json.loads(sys.stdin.read())
panes = [p for w in doc["workspaces"] for t in w["tabs"] for p in leaves(t["layout"])]
print(next(p for p in panes if p["slot"] == int(sys.argv[1])).get(sys.argv[2]))
' "$1" "$2"
}

codex_rollout() {
    local cwd="$1" uuid="$2"
    local dir="$FAKE_HOME/.codex/sessions/2026/07/29"
    mkdir -p "$dir"
    printf '{"payload":{"cwd":"%s"}}\n' "$cwd" >"$dir/rollout-2026-07-29T10-00-00-$uuid.jsonl"
}

@test "snapshot writes the v2 schema envelope" {
    write_snapshot "$(one_pane w6 toolkit "$FAKE_HOME/work/toolkit")"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['schema']")" = "resume-after-reboot/v2" ]
    [ "$(json_field "['backend']")" = "herdr" ]
    [ "$(json_field "['session']")" = "testsession" ]
    [ "$(json_field "['captured'][4]")" = "-" ]
}

@test "snapshot nests panes under their own tab and workspace" {
    write_snapshot '{"workspaces":[{"id":"w8","label":"webapp","tabs":[
        {"id":"w8:t1","label":"agent","layout":{"pane":"w8:p1","cwd":"/w/webapp"}},
        {"id":"w8:t2","label":"server","layout":{"pane":"w8:p2","cwd":"/w/webapp"}}]}]}'

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['workspaces'][0]['label']")" = "webapp" ]
    [ "$(json_field "['workspaces'][0]['workspace_id']")" = "w8" ]
    [ "$(json_field "['workspaces'][0]['tabs'][0]['tab_id']")" = "w8:t1" ]
    [ "$(json_field "['workspaces'][0]['tabs'][1]['tab_id']")" = "w8:t2" ]
    [ "$(json_field "['workspaces'][0]['tabs'][1]['layout']['pane_id']")" = "w8:p2" ]
}

@test "snapshot keeps a tab label that differs from its workspace label" {
    write_snapshot '{"workspaces":[{"id":"w8","label":"webapp","tabs":[
        {"id":"w8:t1","label":"just dev","layout":{"pane":"w8:p1","cwd":"/w/webapp"}}]}]}'

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['workspaces'][0]['tabs'][0]['label']")" = "just dev" ]
}

@test "snapshot records a split with its direction and ratio" {
    write_snapshot '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","layout":{"split":"right","ratio":0.6,"children":[
            {"pane":"wA:p1","cwd":"/w/kalshi","agent":"claude","session":"3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"},
            {"pane":"wA:p2","cwd":"/w/kalshi"}]}}]}]}'

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['workspaces'][0]['tabs'][0]['layout']['type']")" = "split" ]
    [ "$(json_field "['workspaces'][0]['tabs'][0]['layout']['direction']")" = "right" ]
    [ "$(json_field "['workspaces'][0]['tabs'][0]['layout']['ratio']")" = "0.6" ]
    [ "$(json_field "['workspaces'][0]['tabs'][0]['layout']['children'][0]['pane_id']")" = "wA:p1" ]
    [ "$(json_field "['workspaces'][0]['tabs'][0]['layout']['children'][1]['pane_id']")" = "wA:p2" ]
    [ "$(pane_field 1 tool)" = "claude" ]
    [ "$(pane_field 2 tool)" = "shell" ]
}

@test "snapshot nests a split inside a split" {
    write_snapshot '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","layout":{"split":"right","ratio":0.6,"children":[
            {"pane":"wA:p1","cwd":"/w/kalshi"},
            {"split":"down","ratio":0.3,"children":[
                {"pane":"wA:p2","cwd":"/w/kalshi"},
                {"pane":"wA:p3","cwd":"/w/kalshi"}]}]}}]}]}'

    run_snapshot
    [ "$status" -eq 0 ]
    right="['workspaces'][0]['tabs'][0]['layout']['children'][1]"
    [ "$(json_field "${right}['type']")" = "split" ]
    [ "$(json_field "${right}['direction']")" = "down" ]
    [ "$(json_field "${right}['ratio']")" = "0.3" ]
    [ "$(json_field "${right}['children'][0]['pane_id']")" = "wA:p2" ]
    [ "$(json_field "${right}['children'][1]['pane_id']")" = "wA:p3" ]
}

@test "snapshot records which workspace, tab, and pane held focus" {
    write_snapshot '{"focus":{"workspace":"wB","tab":"wB:t1","pane":"wB:p2"},
        "workspaces":[
        {"id":"wA","label":"kalshi","tabs":[{"id":"wA:t1","layout":{"pane":"wA:p1","cwd":"/w/a"}}]},
        {"id":"wB","label":"webapp","active_tab":"wB:t1","tabs":[
            {"id":"wB:t1","focused_pane":"wB:p2","layout":{"split":"down","ratio":0.5,"children":[
                {"pane":"wB:p1","cwd":"/w/b"},{"pane":"wB:p2","cwd":"/w/b"}]}}]}]}'

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['focus']['workspace_id']")" = "wB" ]
    [ "$(json_field "['focus']['tab_id']")" = "wB:t1" ]
    [ "$(json_field "['focus']['pane_id']")" = "wB:p2" ]
    [ "$(json_field "['workspaces'][1]['active_tab_id']")" = "wB:t1" ]
    [ "$(json_field "['workspaces'][1]['tabs'][0]['focused_pane_id']")" = "wB:p2" ]
}

@test "snapshot records a zoomed tab" {
    write_snapshot '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","zoomed":true,"layout":{"split":"right","ratio":0.5,"children":[
            {"pane":"wA:p1","cwd":"/w/a"},{"pane":"wA:p2","cwd":"/w/a"}]}}]}]}'

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['workspaces'][0]['tabs'][0]['zoomed']")" = "True" ]
}

@test "snapshot numbers slots by workspace order, then tab order, then layout order" {
    write_snapshot '{"workspaces":[
        {"id":"wB","label":"second","number":1,"tabs":[
            {"id":"wB:t1","number":2,"layout":{"split":"right","ratio":0.5,"children":[
                {"pane":"wB:p1","cwd":"/w/b"},{"pane":"wB:p2","cwd":"/w/b"}]}}]},
        {"id":"w6","label":"first","number":2,"tabs":[
            {"id":"w6:t1","number":1,"layout":{"pane":"w6:p1","cwd":"/w/a"}}]}]}'

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 pane_id)" = "wB:p1" ]
    [ "$(pane_field 2 pane_id)" = "wB:p2" ]
    [ "$(pane_field 3 pane_id)" = "w6:p1" ]
}

@test "snapshot orders workspaces and tabs by their herdr numbers" {
    write_snapshot '{"workspaces":[
        {"id":"wB","label":"second","number":2,"tabs":[
            {"id":"wB:t9","number":9,"layout":{"pane":"wB:p9","cwd":"/w/b"}},
            {"id":"wB:t1","number":1,"layout":{"pane":"wB:p1","cwd":"/w/b"}}]},
        {"id":"w6","label":"first","number":1,"tabs":[
            {"id":"w6:t1","number":1,"layout":{"pane":"w6:p1","cwd":"/w/a"}}]}]}'

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(json_field "['workspaces'][0]['label']")" = "first" ]
    [ "$(json_field "['workspaces'][1]['tabs'][0]['tab_id']")" = "wB:t1" ]
    [ "$(pane_field 1 pane_id)" = "w6:p1" ]
}

@test "snapshot takes a claude pane's session id straight from herdr" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp" claude 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607)"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "claude" ]
    [ "$(pane_field 1 command)" = "claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" ]
    [ "$(pane_field 1 session_id)" = "3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" ]
    tilde_home="~"
    [ "$(pane_field 1 cwd)" = "$tilde_home/projects/webapp" ]
    [ "$(pane_field 1 pane_id)" = "w8:p1" ]
}

@test "snapshot records claude --continue when herdr reports no session" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp" claude)"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 command)" = "claude --continue" ]
    [ "$(pane_field 1 session_id)" = "None" ]
}

# transcript <cwd> <session> <bytes> — the jsonl claude writes for a session, under the project
# slug it derives from the pane's cwd. Zero bytes is a session that never took a turn.
transcript() {
    local cwd="$1" session="$2" bytes="${3:-1}"
    local slug
    slug=$(printf '%s' "$cwd" | tr -c 'A-Za-z0-9' '-')
    mkdir -p "$FAKE_HOME/.claude/projects/$slug"
    local file="$FAKE_HOME/.claude/projects/$slug/$session.jsonl"
    : >"$file"
    if [ "$bytes" -gt 0 ]; then
        printf '{"type":"user"}\n' >"$file"
    fi
}

# `rc` is `claude rc --spawn worktree` -- Remote Control, whose pre-created placeholder session
# never takes a turn. Resuming its id always fails, so the pane is restored by relaunching.
@test "snapshot restores a Remote Control pane by relaunching it, never by --resume" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp" claude ccc0b0b8-dea4-5101-928d-9c2942e0eccf)"
    process_fixture w8:p1 command "claude rc --permission-mode auto --spawn worktree --name webapp"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "claude-rc" ]
    [ "$(pane_field 1 command)" = "claude rc --permission-mode auto --spawn worktree --name webapp --continue" ]
    [ "$(pane_field 1 session_id)" = "None" ]
}

@test "snapshot refuses --resume for a uuid v5 session id" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp" claude 68df324e-c620-5083-8d52-93e4fa4dad87)"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 command)" = "claude --continue" ]
    [ "$(pane_field 1 session_id)" = "None" ]
}

@test "snapshot refuses --resume when the transcript exists but is empty" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp" claude 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607)"
    transcript "$FAKE_HOME/projects/webapp" 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607 0

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 command)" = "claude --continue" ]
    [ "$(pane_field 1 session_id)" = "None" ]
}

# A missing transcript is not proof the session is dead -- a worktree cwd hashes to a different
# slug -- so herdr's report still wins.
@test "snapshot keeps --resume when no transcript is found for the cwd" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp" claude 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607)"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 command)" = "claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" ]
}

@test "snapshot keeps --resume when the transcript holds a turn" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp" claude 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607)"
    transcript "$FAKE_HOME/projects/webapp" 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607 1

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 command)" = "claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607" ]
}

@test "restore fires a Remote Control pane like any other agent pane" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[
        {"id":"w8","label":"webapp","tabs":[
            {"id":"w8:t1","label":"rc","layout":{"pane":"w8:p1","cwd":"~/projects/webapp",
                "tool":"claude-rc",
                "command":"claude rc --spawn worktree --continue"}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]
    grep -q 'pane run .* claude rc --spawn worktree --continue' "$HERDR_LOG"
}

@test "snapshot takes a codex pane's session id straight from herdr when it reports one" {
    write_snapshot "$(one_pane w6 toolkit "$FAKE_HOME/work/toolkit" codex 019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718)"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "codex" ]
    [ "$(pane_field 1 command)" = "codex resume 019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718" ]
    [ "$(pane_field 1 session_id)" = "019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718" ]
}

@test "snapshot falls back to the rollout index for a codex pane with no reported session" {
    codex_rollout "$FAKE_HOME/projects/dashboard" "019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718"
    write_snapshot "$(one_pane wP dashboard "$FAKE_HOME/projects/dashboard" codex)"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 command)" = "codex resume 019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718" ]
    [ "$(pane_field 1 session_id)" = "019a1b2c-3d4e-7f50-a1b2-c3d4e5f60718" ]
    [[ "$(pane_field 1 note)" == *rollout* ]]
}

@test "snapshot records codex resume --last with a null session id when no rollout matches" {
    write_snapshot "$(one_pane wN notes "$FAKE_HOME/projects/notes" codex)"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 command)" = "codex resume --last" ]
    [ "$(pane_field 1 session_id)" = "None" ]
}

@test "snapshot pairs multiple codex panes in one cwd newest-rollout-first" {
    codex_rollout "$FAKE_HOME/projects/dashboard" "019b2c3d-4e5f-7061-b2c3-d4e5f6071829"
    sleep 1
    codex_rollout "$FAKE_HOME/projects/dashboard" "019c3d4e-5f60-7172-c3d4-e5f607182930"
    write_snapshot "{\"workspaces\":[{\"id\":\"wA\",\"label\":\"dashboard\",\"tabs\":[
        {\"id\":\"wA:t1\",\"layout\":{\"pane\":\"wA:p1\",\"cwd\":\"$FAKE_HOME/projects/dashboard\",\"agent\":\"codex\"}},
        {\"id\":\"wA:t2\",\"layout\":{\"pane\":\"wA:p2\",\"cwd\":\"$FAKE_HOME/projects/dashboard\",\"agent\":\"codex\"}}]}]}"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 session_id)" = "019c3d4e-5f60-7172-c3d4-e5f607182930" ]
    [ "$(pane_field 2 session_id)" = "019b2c3d-4e5f-7061-b2c3-d4e5f6071829" ]
}

@test "snapshot records an agentless pane at an idle shell as a shell pane" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "shell" ]
    [ "$(pane_field 1 command)" = "None" ]
    [ "$(pane_field 1 session_id)" = "None" ]
}

@test "snapshot records an allowlisted foreground command as a command pane" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp")"
    process_fixture "w8:p1" command "just dev"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "command" ]
    [ "$(pane_field 1 command)" = "just dev" ]
    [ "$(pane_field 1 session_id)" = "None" ]
    [ "$(pane_field 1 restore_default)" = "False" ]
}

@test "snapshot treats an unallowlisted foreground program as a shell pane" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    process_fixture "wS:p1" command "vim notes.md"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "shell" ]
}

@test "snapshot records a read-only git viewer and restores it by default" {
    write_snapshot "$(one_pane wG dotfiles "$FAKE_HOME/.dotfiles")"
    process_chain_fixture "wG:p1" \
        "git la" \
        "/opt/homebrew/opt/git/libexec/git-core/git log --graph --decorate" \
        "delta --features default-feature" \
        "less --RAW-CONTROL-CHARS"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "command" ]
    # The alias as typed, not the expansion git resolved it to.
    [ "$(pane_field 1 command)" = "git la" ]
    [ "$(pane_field 1 restore_default)" = "True" ]
}

@test "snapshot resolves a git alias before judging it safe" {
    write_snapshot "$(one_pane wG dotfiles "$FAKE_HOME/.dotfiles")"
    # An alias whose name says nothing, expanding to a subcommand that rewrites history.
    process_chain_fixture "wG:p1" \
        "git ra" \
        "/opt/homebrew/opt/git/libexec/git-core/git rebase --interactive origin/main"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "shell" ]
}

@test "snapshot treats a mutating git command as a shell pane" {
    write_snapshot "$(one_pane wG dotfiles "$FAKE_HOME/.dotfiles")"
    process_fixture "wG:p1" command "git push origin main"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "shell" ]
}

@test "snapshot records a pager holding a file" {
    write_snapshot "$(one_pane wP notes "$FAKE_HOME/notes")"
    process_fixture "wP:p1" command "less CHANGELOG.md"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "command" ]
    [ "$(pane_field 1 command)" = "less CHANGELOG.md" ]
    [ "$(pane_field 1 restore_default)" = "True" ]
}

@test "snapshot treats a pager with no file operand as a shell pane" {
    write_snapshot "$(one_pane wP notes "$FAKE_HOME/notes")"
    # A bare pager is reading a pipe that will not exist after the reboot; re-running it
    # would hang the pane on stdin.
    process_fixture "wP:p1" command "less --RAW-CONTROL-CHARS --quit-if-one-screen"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "shell" ]
}

@test "snapshot records a git TUI as a restorable viewer" {
    write_snapshot "$(one_pane wT dotfiles "$FAKE_HOME/.dotfiles")"
    process_fixture "wT:p1" command "lazygit"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "command" ]
    [ "$(pane_field 1 restore_default)" = "True" ]
}

@test "snapshot records a system monitor as a restorable viewer" {
    write_snapshot "$(one_pane wM dotfiles "$FAKE_HOME/.dotfiles")"
    process_fixture "wM:p1" command "htop"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "command" ]
    [ "$(pane_field 1 restore_default)" = "True" ]
}

@test "snapshot classifies every pane of a split tab on its own" {
    write_snapshot '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","layout":{"split":"down","ratio":0.5,"children":[
            {"pane":"wA:p1","cwd":"/w/kalshi"},
            {"pane":"wA:p2","cwd":"/w/kalshi"}]}}]}]}'
    process_fixture "wA:p2" command "htop"

    run_snapshot
    [ "$status" -eq 0 ]
    [ "$(pane_field 1 tool)" = "shell" ]
    [ "$(pane_field 2 tool)" = "command" ]
    [ "$(pane_field 2 command)" = "htop" ]
}

@test "snapshot --output writes the state file instead of stdout" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"

    run_snapshot --output "$STATE"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run "$PYTHON3" -c "import json,sys; print(json.load(open(sys.argv[1]))['schema'])" "$STATE"
    [ "$output" = "resume-after-reboot/v2" ]
}

@test "restore rejects the flat v1 schema and names the one it wants" {
    printf '{"schema":"resume-after-reboot/v1","backend":"tmux","rows":[]}\n' >"$STATE"

    run_restore "$STATE"
    [ "$status" -ne 0 ]
    [[ "$output" == *"resume-after-reboot/v2"* ]]
}

@test "restore dry run reports the plan and touches nothing" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[
        {"id":"w8","label":"webapp","tabs":[
            {"id":"w8:t1","label":"agent","layout":{"pane":"w8:p1","cwd":"~/projects/webapp",
                "tool":"claude","command":"claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607",
                "session":"3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"}},
            {"id":"w8:t2","label":"shell","layout":{"pane":"w8:p2","cwd":"~/projects/webapp"}}]},
        {"id":"wZ","label":"api-server","tabs":[
            {"id":"wZ:t1","layout":{"pane":"wZ:p1","cwd":"~/projects/api-server",
                "tool":"claude","command":"claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f",
                "session":"7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"}}]}]}'

    run_restore "$STATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
    [[ "$output" == *"2 workspaces"* ]]
    [[ "$output" == *"3 tabs"* ]]
    [[ "$output" == *"agent"* ]]

    run grep -c -e "workspace create" -e "tab create" -e "pane split" -e "pane run" "$HERDR_LOG"
    [ "$output" = "0" ]
}

@test "restore --go rebuilds every captured workspace, even two sharing a cwd" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[
        {"id":"w8","label":"webapp","tabs":[
            {"id":"w8:t1","layout":{"pane":"w8:p1","cwd":"~/projects/webapp"}}]},
        {"id":"wZ","label":"webapp review","tabs":[
            {"id":"wZ:t1","layout":{"pane":"wZ:p1","cwd":"~/projects/webapp"}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -c "workspace create" "$HERDR_LOG"
    [ "$output" = "2" ]

    run grep -F -- "workspace create --cwd $FAKE_HOME/projects/webapp --label webapp --no-focus" "$HERDR_LOG"
    [ "$status" -eq 0 ]

    run grep -F -- "--label webapp review --no-focus" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore --go gives every captured tab its own label" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"w8","label":"webapp","tabs":[
        {"id":"w8:t1","label":"agent","layout":{"pane":"w8:p1","cwd":"~/projects/webapp"}},
        {"id":"w8:t2","label":"server","layout":{"pane":"w8:p2","cwd":"~/projects/webapp"}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    # The workspace's own root tab carries the first tab's label; the rest are created.
    run grep -F -- "tab rename n1:t1 agent" "$HERDR_LOG"
    [ "$status" -eq 0 ]

    run grep -F -- "tab create --workspace n1 --cwd $FAKE_HOME/projects/webapp --label server --no-focus" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore --go rebuilds a split at its captured direction and ratio" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","layout":{"split":"right","ratio":0.6,"children":[
            {"pane":"wA:p1","cwd":"~/work/kalshi","tool":"claude",
             "command":"claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607",
             "session":"3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"},
            {"pane":"wA:p2","cwd":"~/work/kalshi"}]}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -c "tab create" "$HERDR_LOG"
    [ "$output" = "0" ]

    run grep -F -- "pane split --pane n1:p1 --direction right --ratio 0.6 --cwd $FAKE_HOME/work/kalshi --no-focus" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore --go rebuilds a nested split into the pane that holds it" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","layout":{"split":"right","ratio":0.6,"children":[
            {"pane":"wA:p1","cwd":"~/work/kalshi"},
            {"split":"down","ratio":0.3,"children":[
                {"pane":"wA:p2","cwd":"~/work/kalshi"},
                {"pane":"wA:p3","cwd":"~/work/kalshi"}]}]}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -c "pane split" "$HERDR_LOG"
    [ "$output" = "2" ]

    # The nested split divides the pane the outer split created, not the tab's root pane.
    run grep -F -- "pane split --pane n1:s2 --direction down --ratio 0.3" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore --go fires each agent pane into its own pane and reports success" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wA","label":"api-server","tabs":[
        {"id":"wA:t1","layout":{"split":"down","ratio":0.5,"children":[
            {"pane":"wA:p1","cwd":"~/projects/api-server","tool":"claude",
             "command":"claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f",
             "session":"7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"},
            {"pane":"wA:p2","cwd":"~/projects/api-server","tool":"codex",
             "command":"codex resume 019b2c3d-4e5f-7061-b2c3-d4e5f6071829",
             "session":"019b2c3d-4e5f-7061-b2c3-d4e5f6071829"}]}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"FIRING"* ]]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "2" ]

    run grep -F -- "pane run n1:p1 claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f" "$HERDR_LOG"
    [ "$status" -eq 0 ]

    run grep -F -- "pane run n1:s2 codex resume 019b2c3d-4e5f-7061-b2c3-d4e5f6071829" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore --go creates a tab for a shell pane but fires no command into it" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wA","label":"api-server","tabs":[
        {"id":"wA:t1","layout":{"pane":"wA:p1","cwd":"~/projects/api-server"}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -c "workspace create" "$HERDR_LOG"
    [ "$output" = "1" ]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "0" ]
}

@test "restore focuses the captured pane as it creates it" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","focused_pane":"wA:p2","layout":{"split":"right","ratio":0.5,"children":[
            {"pane":"wA:p1","cwd":"~/work/kalshi"},
            {"pane":"wA:p2","cwd":"~/work/kalshi"}]}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -F -- "pane split --pane n1:p1 --direction right --ratio 0.5 --cwd $FAKE_HOME/work/kalshi --focus" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore returns focus to the captured workspace and its active tab" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"focus":{"workspace":"wZ","tab":"wZ:t2","pane":"wZ:p2"},"workspaces":[
        {"id":"w8","label":"webapp","tabs":[
            {"id":"w8:t1","layout":{"pane":"w8:p1","cwd":"~/projects/webapp"}}]},
        {"id":"wZ","label":"api-server","active_tab":"wZ:t2","tabs":[
            {"id":"wZ:t1","layout":{"pane":"wZ:p1","cwd":"~/projects/api-server"}},
            {"id":"wZ:t2","layout":{"pane":"wZ:p2","cwd":"~/projects/api-server"}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    # The second workspace's root pane serves its first tab, so its second tab is created next.
    run grep -F -- "tab focus n2:t3" "$HERDR_LOG"
    [ "$status" -eq 0 ]

    run grep -F -- "workspace focus n2" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore re-zooms a tab captured zoomed" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","zoomed":true,"focused_pane":"wA:p2",
         "layout":{"split":"right","ratio":0.5,"children":[
            {"pane":"wA:p1","cwd":"~/work/kalshi"},
            {"pane":"wA:p2","cwd":"~/work/kalshi"}]}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -F -- "pane zoom --pane n1:s2 --on" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore skips command panes by default and says why" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"w8","label":"webapp","tabs":[
        {"id":"w8:t1","layout":{"pane":"w8:p1","cwd":"~/projects/webapp","tool":"command",
            "command":"just dev","restore_default":false}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    [[ "$output" == *"--commands"* ]]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "0" ]

    run grep -c "workspace create" "$HERDR_LOG"
    [ "$output" = "1" ]
}

@test "restore --commands fires command panes" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"w8","label":"webapp","tabs":[
        {"id":"w8:t1","layout":{"pane":"w8:p1","cwd":"~/projects/webapp","tool":"command",
            "command":"just dev","restore_default":false}}]}]}'

    run_restore "$STATE" --go --commands
    [ "$status" -eq 0 ]

    run grep -F -- "pane run n1:p1 just dev" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore fires a viewer pane without --commands" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    # A pager dies with the reboot, so the EADDRINUSE reasoning that makes dev servers
    # opt-in does not apply to it.
    write_state '{"workspaces":[{"id":"wG","label":"dotfiles","tabs":[
        {"id":"wG:t1","layout":{"pane":"wG:p1","cwd":"~/.dotfiles","tool":"command",
            "command":"git la","restore_default":true}}]}]}'

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -F -- "pane run n1:p1 git la" "$HERDR_LOG"
    [ "$status" -eq 0 ]
}

@test "restore counts viewer panes as firing in its dry-run summary" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wG","label":"dotfiles","tabs":[
        {"id":"wG:t1","layout":{"pane":"wG:p1","cwd":"~/.dotfiles","tool":"command",
            "command":"git la","restore_default":true}}]}]}'

    run_restore "$STATE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 panes to fire"* ]]
}

@test "restore adopts a live workspace with the same label and cwd, on fresh tabs" {
    write_snapshot "$(one_pane w8 webapp "$FAKE_HOME/projects/webapp" claude 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607)"
    write_state '{"workspaces":[{"id":"w8","label":"webapp","tabs":[
        {"id":"w8:t1","layout":{"pane":"w8:p1","cwd":"~/projects/webapp","tool":"claude",
            "command":"claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607",
            "session":"3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"}},
        {"id":"w8:t2","layout":{"pane":"w8:p2","cwd":"~/projects/webapp"}}]}]}'

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
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wA","label":"api-server","tabs":[
        {"id":"wA:t1","layout":{"pane":"wA:p1","cwd":"~/projects/api-server","tool":"claude",
            "command":"claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f",
            "session":"7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"}}]}]}'
    process_fixture "n1:p1" claude "claude --resume b1c2d3e4-f506-4718-8293-a4b5c6d7e8f9"

    run_restore "$STATE" --go
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
    [[ "$output" == *"claude"* ]]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "0" ]
}

@test "restore --limit keeps only the first N workspaces" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[
        {"id":"w1","label":"webapp","tabs":[
            {"id":"w1:t1","layout":{"pane":"w1:p1","cwd":"~/projects/webapp"}}]},
        {"id":"w2","label":"api-server","tabs":[
            {"id":"w2:t1","layout":{"pane":"w2:p1","cwd":"~/projects/api-server"}}]},
        {"id":"w3","label":"notes","tabs":[
            {"id":"w3:t1","layout":{"pane":"w3:p1","cwd":"~/projects/notes"}}]}]}'

    run_restore "$STATE" --limit 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 workspaces"* ]]
    [[ "$output" != *notes* ]]
}

@test "restore --skip drops a pane and collapses the split that held it" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","layout":{"split":"right","ratio":0.5,"children":[
            {"pane":"wA:p1","cwd":"~/work/kalshi","tool":"claude",
             "command":"claude --resume 3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607",
             "session":"3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"},
            {"pane":"wA:p2","cwd":"~/work/kalshi","tool":"claude",
             "command":"claude --resume 7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f",
             "session":"7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"}]}}]}]}'

    run_restore "$STATE" --go --skip 2
    [ "$status" -eq 0 ]

    run grep -c "pane split" "$HERDR_LOG"
    [ "$output" = "0" ]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "1" ]
}

@test "restore --skip drops a whole tab when every pane in it is skipped" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    write_state '{"workspaces":[{"id":"w8","label":"webapp","tabs":[
        {"id":"w8:t1","layout":{"pane":"w8:p1","cwd":"~/projects/webapp"}},
        {"id":"w8:t2","label":"doomed","layout":{"pane":"w8:p2","cwd":"~/projects/webapp"}}]}]}'

    run_restore "$STATE" --go --skip 2
    [ "$status" -eq 0 ]
    [[ "$output" != *doomed* ]]

    run grep -c "tab create" "$HERDR_LOG"
    [ "$output" = "0" ]
}

@test "snapshot and restore agree on the document one writes and the other reads" {
    write_snapshot '{"focus":{"workspace":"wA","tab":"wA:t1","pane":"wA:p2"},
        "workspaces":[{"id":"wA","label":"kalshi","tabs":[
        {"id":"wA:t1","label":"agents","focused_pane":"wA:p2",
         "layout":{"split":"right","ratio":0.6,"children":[
            {"pane":"wA:p1","cwd":"/w/kalshi","agent":"claude",
             "session":"3f2a1b0c-4d5e-4f60-8a71-b2c3d4e5f607"},
            {"pane":"wA:p2","cwd":"/w/kalshi","agent":"claude",
             "session":"7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f"}]}}]}]}'

    run_snapshot --output "$STATE"
    [ "$status" -eq 0 ]

    # The reboot took that session with it, so restore meets an unrelated live one.
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    run_restore "$STATE" --go
    [ "$status" -eq 0 ]

    run grep -F -- "pane split --pane n1:p1 --direction right --ratio 0.6 --cwd /w/kalshi --focus" "$HERDR_LOG"
    [ "$status" -eq 0 ]

    run grep -c "pane run" "$HERDR_LOG"
    [ "$output" = "2" ]
}

@test "restore reads .llm/resume-after-reboot-state.json when given no state file" {
    write_snapshot "$(one_pane wS toolkit "$FAKE_HOME/work/toolkit")"
    project="$BATS_TEST_TMPDIR/project"
    mkdir -p "$project/.llm"
    STATE="$project/.llm/resume-after-reboot-state.json"
    write_state '{"workspaces":[{"id":"wA","label":"api-server","tabs":[
        {"id":"wA:t1","layout":{"pane":"wA:p1","cwd":"~/projects/api-server"}}]}]}'

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
