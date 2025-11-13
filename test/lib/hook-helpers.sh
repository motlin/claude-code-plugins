#!/bin/bash

set -Eeuo pipefail

create_test_json() {
  local cwd="${1:-/test/directory}"
  local tool_name="${2:-TestTool}"
  local extra_fields="${3:-}"

  local json
  json=$(jq --null-input \
    --arg cwd "$cwd" \
    --arg tool_name "$tool_name" \
    '{
      cwd: $cwd,
      tool_name: $tool_name
    }')

  if [ -n "$extra_fields" ]; then
    json=$(echo "$json" | jq ". + $extra_fields")
  fi

  echo "$json"
}

run_hook_script() {
  local script_path="$1"
  local input_json="$2"
  shift 2
  local args=("$@")

  local output
  local exit_code=0

  output=$(echo "$input_json" | "$script_path" "${args[@]}" 2>&1) || exit_code=$?

  echo "$output"
  return $exit_code
}

validate_hooks_json() {
  local hooks_file="$1"

  if [ ! -f "$hooks_file" ]; then
    echo "File not found: $hooks_file"
    return 1
  fi

  if ! jq empty "$hooks_file" 2>/dev/null; then
    echo "Invalid JSON in $hooks_file"
    return 1
  fi

  local hooks
  hooks=$(jq --raw-output '.hooks | keys[]' "$hooks_file" 2>/dev/null || echo "")

  if [ -z "$hooks" ]; then
    echo "No hooks defined in $hooks_file"
    return 1
  fi

  return 0
}

get_hook_commands() {
  local hooks_file="$1"
  local event_type="$2"

  jq --raw-output \
    --arg event "$event_type" \
    '.hooks[$event][]?.hooks[]?.command // empty' \
    "$hooks_file"
}

get_hook_type() {
  local hooks_file="$1"
  local event_type="$2"
  local hook_index="${3:-0}"

  jq --raw-output \
    --arg event "$event_type" \
    --argjson index "$hook_index" \
    '.hooks[$event][]?.hooks[$index]?.type // "missing"' \
    "$hooks_file"
}

check_hook_type_consistency() {
  local hooks_file="$1"
  local script_path="$2"

  local commands
  commands=$(jq --raw-output '.hooks[][]?.hooks[]?.command // empty' "$hooks_file")

  local inconsistent=0
  while IFS= read -r command; do
    if [[ "$command" == *"$script_path"* ]]; then
      local reads_stdin=0

      if grep -q 'json=$(cat)' "$script_path" 2>/dev/null; then
        reads_stdin=1
      fi

      local event_types
      event_types=$(jq --raw-output \
        --arg cmd "$command" \
        '.hooks | to_entries[] | select(.value[]?.hooks[]?.command == $cmd) | .key' \
        "$hooks_file")

      while IFS= read -r event_type; do
        local hook_type
        hook_type=$(get_hook_type "$hooks_file" "$event_type" 0)

        if [ "$reads_stdin" -eq 1 ] && [ "$hook_type" != "command" ]; then
          echo "Inconsistency: $script_path reads stdin but hook type is '$hook_type' for event $event_type"
          inconsistent=1
        fi
      done <<< "$event_types"
    fi
  done <<< "$commands"

  return $inconsistent
}
