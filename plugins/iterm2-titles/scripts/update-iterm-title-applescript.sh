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

osascript - "$title" <<'EOF' 2>/dev/null || true
on run argv
  set newTitle to item 1 of argv
  tell application "iTerm"
    if (count of windows) > 0 then
      tell current window
        tell current tab
          set title to newTitle
        end tell
      end tell
    end if
  end tell
end run
EOF
