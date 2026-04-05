#!/bin/bash

set -Eeuo pipefail

json=$(cat)

icon="${1:-}"

if [ "${TERM_PROGRAM:-}" != "ghostty" ]; then
    exit 0
fi

cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")

# Find the TTY device for the claude process.
# Hook scripts run in subprocesses whose stdout is captured by Claude Code,
# so we must write the escape sequence directly to the terminal device.
tty_device=""
pid=$$
while [ "$pid" -gt 1 ]; do
    tty_device=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$tty_device" ] && [ "$tty_device" != "??" ]; then
        break
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done

if [ -z "$tty_device" ] || [ "$tty_device" = "??" ]; then
    exit 0
fi

printf '\e]2;%s\a' "$icon $dir_name" >"/dev/$tty_device"
