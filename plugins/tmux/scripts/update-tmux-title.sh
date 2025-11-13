#!/bin/bash

set -Eeuo pipefail

indicator="${1:-}"

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")

claude_session_id="${CLAUDE_SESSION_ID:-}"
if [ -n "$claude_session_id" ]; then
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-code/tmux-panes"
  pane_file="$cache_dir/$claude_session_id"
  if [ -f "$pane_file" ]; then
    tmux_pane=$(cat "$pane_file")
    target=$(tmux display-message -p -t "$tmux_pane" "#{session_id}:#{window_id}" 2>/dev/null || echo "")
    if [ -n "$target" ]; then
      tmux rename-window -t "$target" "$indicator $dir_name"
      exit 0
    fi
  fi
fi

tmux rename-window "$indicator $dir_name"
