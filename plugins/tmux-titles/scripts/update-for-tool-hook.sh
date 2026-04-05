#!/bin/bash

set -Eeuo pipefail

json=$(cat)

if [ -z "${TMUX:-}" ]; then
    exit 0
fi

if [ -z "${TMUX_PANE:-}" ]; then
    exit 0
fi

tool_name=$(echo "$json" | jq --raw-output '.tool_name')

case "$tool_name" in
    Bash)
        icon='$'
        ;;
    Create | Edit | Write | MultiEdit)
        icon='✎'
        ;;
    Read)
        icon='…'
        ;;
    AskUserQuestion)
        icon='?'
        ;;
    *)
        icon='✻'
        ;;
esac

"$(dirname "${BASH_SOURCE[0]}")/update-tmux-title.sh" "$icon"
