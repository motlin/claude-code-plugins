#!/bin/bash

set -Eeuo pipefail

# Consume stdin (hook protocol sends JSON, but we don't need it)
cat >/dev/null

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

tmux set-option -wq -t "$target" @claude_indicator "$indicator"
