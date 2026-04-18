#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$PROJECT_ROOT/plugins/stop-phrase-guard/scripts/stop-phrase-guard.sh"
}

@test "stop-phrase-guard hooks.json is valid JSON" {
  validate_hooks_json "$PROJECT_ROOT/plugins/stop-phrase-guard/hooks/hooks.json"
}

@test "stop-phrase-guard hooks.json has Stop event" {
  hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/stop-phrase-guard/hooks/hooks.json")
  [[ "$hooks" =~ "Stop" ]]
}

@test "stop-phrase-guard hook commands point to existing scripts" {
  all_exist=0
  commands=$(get_hook_commands "$PROJECT_ROOT/plugins/stop-phrase-guard/hooks/hooks.json" "Stop")
  for cmd in $commands; do
    resolved_cmd=$(echo "$cmd" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$PROJECT_ROOT/plugins/stop-phrase-guard|g")
    if [ ! -f "$resolved_cmd" ]; then
      echo "Script not found: $resolved_cmd"
      all_exist=1
    fi
  done
  [ "$all_exist" -eq 0 ]
}

@test "stop-phrase-guard hooks use command type" {
  hook_type=$(jq --raw-output '.hooks.Stop[0].hooks[0].type' "$PROJECT_ROOT/plugins/stop-phrase-guard/hooks/hooks.json")
  [ "$hook_type" = "command" ]
}

@test "stop-phrase-guard script is executable" {
  [ -x "$SCRIPT" ]
}

@test "stop-phrase-guard allows stop when message is clean" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: "Task complete. All tests pass."}')
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop-phrase-guard allows stop when stop_hook_active is true" {
  input=$(jq --null-input '{stop_hook_active: true, last_assistant_message: "This is a pre-existing failure."}')
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop-phrase-guard allows stop when last_assistant_message is empty" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: ""}')
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop-phrase-guard blocks on ownership-dodging phrase" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: "That test failure is pre-existing."}')
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.decision')
  [ "$decision" = "block" ]
  reason=$(echo "$output" | jq --raw-output '.reason')
  [[ "$reason" =~ "STOP HOOK VIOLATION" ]]
  [[ "$reason" =~ "NOTHING IS PRE-EXISTING" ]]
}

@test "stop-phrase-guard blocks on session-length quitting phrase" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: "This seems like a good stopping point."}')
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.decision')
  [ "$decision" = "block" ]
}

@test "stop-phrase-guard blocks on permission-seeking phrase" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: "Would you like me to continue?"}')
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.decision')
  [ "$decision" = "block" ]
}

@test "stop-phrase-guard matching is case-insensitive" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: "PRE-EXISTING bug, skipping."}')
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.decision')
  [ "$decision" = "block" ]
}
