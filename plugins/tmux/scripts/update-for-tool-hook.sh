#!/bin/bash

set -euo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tool_name=$(cat | "$script_dir/extract-tool-name.sh")
icon=$("$script_dir/map-tool-to-icon.sh" "$tool_name")
"$script_dir/update-tmux-title.sh" "$icon"
