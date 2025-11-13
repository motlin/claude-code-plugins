#!/bin/bash

set -Eeuo pipefail

if [ -n "${TMUX_PANE:-}" ]; then
  claude_session_id="${CLAUDE_SESSION_ID:-}"
  if [ -n "$claude_session_id" ]; then
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-code/tmux-panes"
    mkdir -p "$cache_dir"
    echo "$TMUX_PANE" > "$cache_dir/$claude_session_id"

    find "$cache_dir" -type f -mtime +7 -delete 2>/dev/null || true
  fi
fi
