#!/bin/bash

set -Eeuo pipefail

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

current_name=$(tmux display-message -p -t "$target" "#{window_name}" 2>/dev/null || echo "")
base_name=$(echo "$current_name" | sed -E 's/^[✻✓○?⌫$✎…] //' | sed -E 's/ [✻✓○?⌫$✎…]$//')

tmux rename-window -t "$target" "$base_name"
