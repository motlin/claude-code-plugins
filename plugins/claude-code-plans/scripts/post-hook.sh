#!/usr/bin/env bash

set -Eeuo pipefail

# Consume stdin (hook protocol sends JSON, but we don't need it)
cat >/dev/null

# Usage: post-hook.sh <event_name> [key=ENV_VAR ...]
# Always sends session_id and hook_event_name.
# Extra key=ENV_VAR pairs add fields from environment variables.

event_name="${1:?Usage: post-hook.sh <event_name> [key=ENV_VAR ...]}"
shift

# jq filter — $ENV and $event are jq context variables, not shell variables.
# shellcheck disable=SC2016
filter='.session_id = ($ENV.CLAUDE_SESSION_ID // "") | .hook_event_name = $event'

for pair in "$@"; do
    key="${pair%%=*}"
    env_var="${pair#*=}"
    filter="$filter | .$key = (\$ENV.$env_var // \"\")"
done

curl -sX POST http://localhost:8899/api/hook \
    --connect-timeout 1 --max-time 2 \
    -H 'Content-Type: application/json' \
    -d "$(echo '{}' | jq -c --arg event "$event_name" "$filter")" \
    >/dev/null 2>&1 || true
