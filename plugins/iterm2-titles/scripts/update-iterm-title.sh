#!/bin/bash

set -Eeuo pipefail

if [ "${LC_TERMINAL:-}" != "iTerm2" ]; then
  exit 0
fi

indicator="${1:-}"

json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")

printf "\e]0;%s %s\a" "$indicator" "$dir_name"
