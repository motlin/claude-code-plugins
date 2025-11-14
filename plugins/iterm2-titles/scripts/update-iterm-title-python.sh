#!/bin/bash

set -Eeuo pipefail

if [ "${LC_TERMINAL:-}" != "iTerm2" ]; then
  exit 0
fi

indicator="${1:-}"

json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")

title="$indicator $dir_name"

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$script_dir/set_tab_title.py" "$title" 2>/dev/null || true
