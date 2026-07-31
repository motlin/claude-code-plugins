#!/bin/bash

set -Eeuo pipefail

hook_input=$(cat)

if [ -z "${HERDR_TAB_ID:-}" ]; then
    exit 0
fi

transcript_path=$(jq --exit-status --raw-output '.transcript_path' <<<"$hook_input")
if [ ! -f "$transcript_path" ]; then
    exit 0
fi

custom_title=$(
    jq --raw-input --raw-output '
        fromjson
        | select(
            .type == "custom-title"
            and (.customTitle | type == "string")
            and (.customTitle | length > 0)
        )
        | .customTitle
    ' "$transcript_path" | tail -n 1
)

if [ -z "$custom_title" ]; then
    exit 0
fi

herdr tab rename "$HERDR_TAB_ID" "$custom_title" >/dev/null
