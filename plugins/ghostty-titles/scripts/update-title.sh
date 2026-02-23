#!/bin/bash

set -Eeuo pipefail

json=$(cat)

icon="${1:-}"

if [ "${TERM_PROGRAM:-}" != "ghostty" ]; then
  exit 0
fi

cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")

printf '\033]0;%s\007' "$icon $dir_name"
