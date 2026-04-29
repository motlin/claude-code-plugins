#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
    exit 0
fi

# Block recursive rm (suggests trash instead)
if [[ "$command" =~ rm[[:space:]]+-[^[:space:]]*[rR] ]] ||
    [[ "$command" =~ rm[[:space:]]+--recursive ]]; then
    echo "Recursive rm is destructive and cannot be undone. Use 'trash' instead of 'rm -r' to safely delete files." >&2
    exit 2
fi
