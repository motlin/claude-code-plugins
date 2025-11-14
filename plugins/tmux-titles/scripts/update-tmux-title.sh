#!/bin/bash

set -Eeuo pipefail

indicator="${1:-}"

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

if [ -z "${TMUX_PANE:-}" ]; then
  exit 0
fi

json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")

target=$(tmux display-message -p -t "$TMUX_PANE" "#{session_id}:#{window_id}" 2>/dev/null || echo "")
if [ -n "$target" ]; then
  tmux rename-window -t "$target" "$indicator $dir_name"
fi
