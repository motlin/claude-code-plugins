#!/bin/bash

set -euo pipefail

indicator="${1:-}"

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

base_name=$("$script_dir/extract-base-window-name.sh")

tmux rename-window "$indicator $base_name"
