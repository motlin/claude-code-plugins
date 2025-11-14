#!/bin/bash

set -Eeuo pipefail

# Only run if we're in iTerm2
if [ -z "${ITERM_SESSION_ID:-}" ]; then
  exit 0
fi

ITERM_SESSION_ID="${ITERM_SESSION_ID:-}"
TERMID="${ITERM_SESSION_ID%%:*}"
PID_FILE="/tmp/iterm2-monitor-${TERMID}.pid"

# Kill the monitor process if it exists
if [ -f "${PID_FILE}" ]; then
  PID=$(cat "${PID_FILE}")
  if kill -0 "${PID}" 2>/dev/null; then
    kill "${PID}" 2>/dev/null || true
  fi
  rm -f "${PID_FILE}"
fi
