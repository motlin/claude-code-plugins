#!/bin/bash

set -Eeuo pipefail

hook_input=$(cat)

if [ -z "${HERDR_TAB_ID:-}" ]; then
    exit 0
fi

tab_label=$(herdr tab get "$HERDR_TAB_ID" 2>/dev/null | jq --raw-output '.result.tab.label // empty') || exit 0

# Herdr labels unnamed tabs with their number.
if [[ -z "$tab_label" || "$tab_label" =~ ^[0-9]+$ ]]; then
    exit 0
fi

jq --compact-output --arg title "$tab_label" \
    '{hookSpecificOutput: {hookEventName: .hook_event_name, sessionTitle: $title}}' <<<"$hook_input"
