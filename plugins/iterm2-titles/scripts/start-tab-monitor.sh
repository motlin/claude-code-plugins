#!/bin/bash

set -Eeuo pipefail

# Only run if we're in iTerm2
if [ -z "${ITERM_SESSION_ID:-}" ]; then
  exit 0
fi

SCRIPT_DIR="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ITERM_SESSION_ID="${ITERM_SESSION_ID:-}"
TERMID="${ITERM_SESSION_ID%%:*}"
PID_FILE="/tmp/iterm2-monitor-${TERMID}.pid"

# Launch the monitor in the background
nohup "${SCRIPT_DIR}/monitor-tab-focus.py" > /dev/null 2>&1 &

# Store the PID for cleanup
echo $! > "${PID_FILE}"
