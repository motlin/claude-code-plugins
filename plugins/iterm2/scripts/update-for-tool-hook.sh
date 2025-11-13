#!/bin/bash

set -euo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

json=$(cat)
tool_name=$(echo "$json" | jq --raw-output '.tool_name // ""')
dir_name=$(echo "$json" | jq --raw-output '.cwd // ""' | xargs basename)
icon=$("$script_dir/map-tool-to-icon.sh" "$tool_name")
"$script_dir/update-iterm-title.sh" "$icon" "$dir_name"
