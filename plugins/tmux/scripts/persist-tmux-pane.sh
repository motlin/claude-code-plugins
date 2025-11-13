#!/bin/bash

set -Eeuo pipefail

if [ -n "${TMUX_PANE:-}" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export TMUX_PANE='$TMUX_PANE'" >> "$CLAUDE_ENV_FILE"
fi
