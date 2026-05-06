#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command')"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

printf '[%s] %s\n' "$timestamp" "$command" >>~/.claude/bash-commands.log
