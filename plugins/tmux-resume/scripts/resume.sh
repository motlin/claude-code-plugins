#!/bin/bash

set -Eeuo pipefail

if [ -z "${TMUX:-}" ]; then
    exit 0
fi

state_file="$HOME/.claude/tmux-resume/last-capture.json"

has_claude_descendant() {
    local root_pid=$1
    local processes

    processes=$(ps -axo pid=,ppid=,comm=)
    awk -v root_pid="$root_pid" '
        {
            process_id = $1
            parent[process_id] = $2
            executable[process_id] = $3
        }
        END {
            for (process_id in parent) {
                command = executable[process_id]
                sub(/^.*\//, "", command)
                if (command != "claude") {
                    continue
                }

                ancestor = parent[process_id]
                while (ancestor != "" && ancestor != 0) {
                    if (ancestor == root_pid) {
                        exit 0
                    }
                    ancestor = parent[ancestor]
                }
            }
            exit 1
        }
    ' <<<"$processes"
}

if [ ! -f "$state_file" ]; then
    printf 'No capture state found at %s; nothing to resume.\n' "$state_file"
    exit 0
fi

if ! jq --exit-status '
    type == "array" and all(.[];
        (.tmux_session | type == "string" and length > 0) and
        (.window_index | type == "number" and floor == . and . >= 0) and
        (.pane_index | type == "number" and floor == . and . >= 0) and
        (.cwd | type == "string") and
        (.session_id | type == "string" and test("^[0-9a-f-]{36}$"))
    )
' "$state_file" >/dev/null; then
    printf 'ERROR: Invalid capture state in %s.\n' "$state_file" >&2
    exit 1
fi

relaunched=0
skipped=0

while IFS= read -r entry; do
    tmux_session=$(jq --raw-output '.tmux_session' <<<"$entry")
    window_index=$(jq --raw-output '.window_index' <<<"$entry")
    pane_index=$(jq --raw-output '.pane_index' <<<"$entry")
    recorded_cwd=$(jq --raw-output '.cwd' <<<"$entry")
    session_id=$(jq --raw-output '.session_id' <<<"$entry")
    target="$tmux_session:$window_index.$pane_index"

    if ! restored_cwd=$(tmux display-message -p -t "$target" '#{pane_current_path}'); then
        printf 'WARN: %s was not restored; skipping Claude session %s.\n' "$target" "$session_id" >&2
        ((skipped += 1))
        continue
    fi

    if [ "$restored_cwd" != "$recorded_cwd" ]; then
        printf 'WARN: %s cwd is %s, expected %s; skipping Claude session %s.\n' \
            "$target" "$restored_cwd" "$recorded_cwd" "$session_id" >&2
        ((skipped += 1))
        continue
    fi

    if ! pane_pid=$(tmux display-message -p -t "$target" '#{pane_pid}'); then
        printf 'WARN: %s disappeared before relaunch; skipping Claude session %s.\n' \
            "$target" "$session_id" >&2
        ((skipped += 1))
        continue
    fi

    if has_claude_descendant "$pane_pid"; then
        printf 'WARN: %s already has Claude running; skipping Claude session %s.\n' \
            "$target" "$session_id" >&2
        ((skipped += 1))
        continue
    fi

    resume_command="claude --resume $session_id"
    tmux send-keys -t "$target" "$resume_command" Enter
    printf 'Relaunched Claude session %s in %s.\n' "$session_id" "$target"
    ((relaunched += 1))
done < <(jq --compact-output '.[]' "$state_file")

printf 'Resume summary: relaunched %d, skipped %d.\n' "$relaunched" "$skipped"
