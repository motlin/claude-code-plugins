#!/bin/bash

set -Eeuo pipefail

json=$(cat)

indicator="${1:-}"

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

if [ -z "${TMUX_PANE:-}" ]; then
  exit 0
fi

target=$(tmux display-message -p -t "$TMUX_PANE" "#{session_id}:#{window_id}" 2>/dev/null || echo "")
if [ -z "$target" ]; then
  exit 0
fi

mode="${TMUX_TITLES_MODE:-directory}"
position="${TMUX_TITLES_POSITION:-prefix}"

if [ "$mode" = "window" ]; then
  current_name=$(tmux display-message -p -t "$target" "#{window_name}" 2>/dev/null || echo "")
  base_name=$(echo "$current_name" | sed -E 's/^[✻✓○?⌫$✎…] //' | sed -E 's/ [✻✓○?⌫$✎…]$//')
else
  cwd=$(echo "$json" | jq --raw-output '.cwd')
  base_name=$(basename "$cwd")
fi

if [ "$position" = "suffix" ]; then
  tmux rename-window -t "$target" "$base_name $indicator"
else
  tmux rename-window -t "$target" "$indicator $base_name"
fi
