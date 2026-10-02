#!/usr/bin/env bash

set -Eeuo pipefail

json="$(cat)"
event_name="${1:?Usage: post-hook.sh <event_name>}"

payload="$(printf '%s' "$json" | jq --compact-output --arg event "$event_name" '
    {
        session_id: (.session_id // ""),
        hook_event_name: $event
    } +
    if $event == "SessionStart" then {
        cwd: (.cwd // ""),
        model: (.model // "")
    } elif $event == "PostToolUse" then {
        tool_name: (.tool_name // "")
    } elif $event == "TaskCompleted" then {
        task_id: (.task_id // ""),
        task_subject: (.task_subject // "")
    } elif $event == "WorktreeCreate" then {
        name: (.name // "")
    } else {} end
')"

curl -sX POST http://localhost:8899/api/hook \
    --connect-timeout 1 --max-time 2 \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    >/dev/null 2>&1 || true
