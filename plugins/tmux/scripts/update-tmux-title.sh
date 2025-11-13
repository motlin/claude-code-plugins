#!/bin/bash

set -Eeuo pipefail

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

indicator="${1:-}"

json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")

printf '\033k%s %s\033\\' "$indicator" "$dir_name"
