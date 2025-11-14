#!/bin/bash

set -Eeuo pipefail

if [ "${LC_TERMINAL:-}" != "iTerm2" ]; then
  exit 0
fi

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

json=$(cat)
tool_name=$(echo "$json" | jq --raw-output '.tool_name')

case "$tool_name" in
  Bash)
    icon='$'
    ;;
  Create|Edit|Write|MultiEdit)
    icon='✎'
    ;;
  Read)
    icon='…'
    ;;
  *)
    icon='✻'
    ;;
esac

echo "$json" | "$script_dir/update-iterm-title-python.sh" "$icon"
