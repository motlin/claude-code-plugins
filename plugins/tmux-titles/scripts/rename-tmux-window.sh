#!/bin/bash

set -Eeuo pipefail

json=$(cat)

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

if [ -z "${TMUX_PANE:-}" ]; then
  exit 0
fi

prompt=$(echo "$json" | jq --raw-output '.prompt')

if [[ "$prompt" != /rename\ * ]]; then
  exit 0
fi

name=$(echo "$prompt" | sed 's|^/rename ||')

if [ -z "$name" ]; then
  exit 0
fi

target=$(tmux display-message -p -t "$TMUX_PANE" "#{session_id}:#{window_id}" 2>/dev/null || echo "")
if [ -z "$target" ]; then
  exit 0
fi

tmux rename-window -t "$target" "$name" 2>/dev/null || true
