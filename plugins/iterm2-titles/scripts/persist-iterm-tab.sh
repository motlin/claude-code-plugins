#!/bin/bash

set -Eeuo pipefail

if [ "${LC_TERMINAL:-}" != "iTerm2" ]; then
  exit 0
fi

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$script_dir/persist-iterm-tab.py" 2>/dev/null || true
