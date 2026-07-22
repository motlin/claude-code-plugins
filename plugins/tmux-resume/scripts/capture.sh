#!/bin/bash

set -Eeuo pipefail

if [ -z "${TMUX:-}" ]; then
    exit 0
fi

state_directory="$HOME/.claude/tmux-resume"
state_file="$state_directory/last-capture.json"
captured_at=$(date)
pane_format=$'#{session_name}\t#{window_index}\t#{window_name}\t#{pane_index}\t#{pane_id}\t#{pane_current_path}\t#{pane_pid}'
processes=$(ps -axo pid=,ppid=,comm=)

has_claude_descendant() {
    local root_pid=$1

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

pane_list=$(tmux list-panes -a -F "$pane_format")
entries='[]'
matched=0
live_claude=0
no_footer=0

while IFS=$'\t' read -r tmux_session window_index window_name pane_index pane_id cwd pane_pid; do
    pane_label="$tmux_session:$window_index.$pane_index ($window_name)"

    if has_claude_descendant "$pane_pid"; then
        printf 'WARN: %s still has Claude running; exit this session before capturing.\n' "$pane_label" >&2
        ((live_claude += 1))
        continue
    fi

    scrollback=$(tmux capture-pane -p -t "$pane_id" -S -5000)
    resume_command=$(grep -E '^claude --resume [0-9a-f-]{36}$' <<<"$scrollback" | tail -n 1 || true)
    if [ -z "$resume_command" ]; then
        ((no_footer += 1))
        continue
    fi

    session_id=${resume_command#claude --resume }
    entries=$(jq --compact-output \
        --arg tmux_session "$tmux_session" \
        --argjson window_index "$window_index" \
        --arg window_name "$window_name" \
        --argjson pane_index "$pane_index" \
        --arg cwd "$cwd" \
        --arg session_id "$session_id" \
        --arg resume_command "$resume_command" \
        --arg captured_at "$captured_at" \
        '. + [{
            tmux_session: $tmux_session,
            window_index: $window_index,
            window_name: $window_name,
            pane_index: $pane_index,
            cwd: $cwd,
            session_id: $session_id,
            resume_command: $resume_command,
            captured_at: $captured_at
        }]' <<<"$entries")
    ((matched += 1))
done <<<"$pane_list"

mkdir -p "$state_directory"
printf '%s\n' "$entries" >"$state_file"

printf 'Capture summary: matched %d, skipped live Claude %d, no footer %d.\n' \
    "$matched" "$live_claude" "$no_footer"
printf 'State written to %s\n' "$state_file"
