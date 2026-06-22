#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
    exit 0
fi

# Block recursive rm (suggests trash instead).
# Match rm as a command word (line start, whitespace, separator, or path slash),
# then a recursive flag anywhere among its arguments before the next command
# separator. This catches flags after operands ('rm dir -rf') and path-invoked
# rm ('/bin/rm -rf'), while leaving words ending in rm ('charm -rf') and flags on
# a later command ('rm foo && ls -R') alone.
if [[ "$command" =~ (^|[[:space:]\;\&\|\(/])rm[[:space:]][^\;\&\|]*(-[^[:space:]]*[rR]|--recursive) ]]; then
    echo "Recursive rm is destructive and cannot be undone. Use 'trash' instead of 'rm -r' to safely delete files." >&2
    exit 2
fi
