#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$PROJECT_ROOT/plugins/bash-guards/scripts/validate-bash.sh"
}

@test "bash-guards hooks.json is valid JSON" {
  validate_hooks_json "$PROJECT_ROOT/plugins/bash-guards/hooks/hooks.json"
}

@test "bash-guards hooks.json has PreToolUse event" {
  hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/bash-guards/hooks/hooks.json")
  [[ "$hooks" =~ "PreToolUse" ]]
}

@test "bash-guards hook commands point to existing scripts" {
  all_exist=0
  commands=$(get_hook_commands "$PROJECT_ROOT/plugins/bash-guards/hooks/hooks.json" "PreToolUse")
  for cmd in $commands; do
    resolved_cmd=$(echo "$cmd" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$PROJECT_ROOT/plugins/bash-guards|g")
    if [ ! -f "$resolved_cmd" ]; then
      echo "Script not found: $resolved_cmd"
      all_exist=1
    fi
  done
  [ "$all_exist" -eq 0 ]
}

@test "bash-guards script is executable" {
  [ -x "$SCRIPT" ]
}

@test "bash-guards allows normal commands" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"ls -la\"}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "bash-guards allows empty command" {
  run bash -c "echo '{\"tool_input\":{}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "bash-guards allows non-recursive rm" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"rm foo.txt\"}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "bash-guards denies rm -r" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"rm -r /tmp/foo\"}}' | '$SCRIPT'"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "trash" ]]
}

@test "bash-guards denies rm -rf" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"rm -rf /tmp/foo\"}}' | '$SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "bash-guards denies rm -R" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"rm -R /tmp/foo\"}}' | '$SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "bash-guards denies rm -fr" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"rm -fr /tmp/foo\"}}' | '$SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "bash-guards denies rm --recursive" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"rm --recursive /tmp/foo\"}}' | '$SCRIPT'"
  [ "$status" -eq 2 ]
}
