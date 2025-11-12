#!/bin/bash

set -euo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

json=$(cat)
tool_name=$(echo "$json" | "$script_dir/extract-tool-name.sh")
dir_name=$(echo "$json" | "$script_dir/extract-base-window-name.sh")
icon=$("$script_dir/map-tool-to-icon.sh" "$tool_name")
"$script_dir/update-tmux-title.sh" "$icon" "$dir_name"
