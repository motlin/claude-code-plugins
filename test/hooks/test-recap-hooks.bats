#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$PROJECT_ROOT/plugins/recap/scripts/recap-guard.sh"
  FOOTER=$'📌 You asked: Add a recap footer.\n🔗 PR #42 — https://example.com/pull/42'
}

@test "recap hooks.json is valid JSON" {
  validate_hooks_json "$PROJECT_ROOT/plugins/recap/hooks/hooks.json"
}

@test "recap hooks.json has Stop event" {
  hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/recap/hooks/hooks.json")
  [[ "$hooks" =~ "Stop" ]]
}

@test "recap hook commands point to existing scripts" {
  all_exist=0
  commands=$(get_hook_commands "$PROJECT_ROOT/plugins/recap/hooks/hooks.json" "Stop")
  for command in $commands; do
    resolved_command="${command//\$\{CLAUDE_PLUGIN_ROOT\}/$PROJECT_ROOT/plugins/recap}"
    if [ ! -f "$resolved_command" ]; then
      echo "Script not found: $resolved_command"
      all_exist=1
    fi
  done
  [ "$all_exist" -eq 0 ]
}

@test "recap hooks use command type" {
  hook_type=$(jq --raw-output '.hooks.Stop[0].hooks[0].type' "$PROJECT_ROOT/plugins/recap/hooks/hooks.json")
  [ "$hook_type" = "command" ]
}

@test "recap script is executable" {
  [ -x "$SCRIPT" ]
}

@test "recap allows stop when both footer lines are present" {
  input=$(jq --null-input --arg message "Work done.

$FOOTER" '{stop_hook_active: false, last_assistant_message: $message}')
  run run_hook_script "$SCRIPT" "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "recap allows a None link line" {
  input=$(jq --null-input --arg message "Answered the question.

📌 You asked: Explain how the parser works.
🔗 None" '{stop_hook_active: false, last_assistant_message: $message}')
  run run_hook_script "$SCRIPT" "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "recap blocks when the footer is missing" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: "Work done."}')
  run run_hook_script "$SCRIPT" "$input"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.decision')
  [ "$decision" = "block" ]
}

@test "recap block reason names both footer lines" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: "Work done."}')
  run run_hook_script "$SCRIPT" "$input"
  reason=$(echo "$output" | jq --raw-output '.reason')
  [[ "$reason" == *"📌 You asked:"* ]]
  [[ "$reason" == *"🔗"* ]]
}

@test "recap blocks when only the recap line is present" {
  input=$(jq --null-input --arg message "Work done.

📌 You asked: Add a recap footer." '{stop_hook_active: false, last_assistant_message: $message}')
  run run_hook_script "$SCRIPT" "$input"
  decision=$(echo "$output" | jq --raw-output '.decision')
  [ "$decision" = "block" ]
}

@test "recap blocks when only the link line is present" {
  input=$(jq --null-input --arg message "Work done.

🔗 https://example.com/pull/42" '{stop_hook_active: false, last_assistant_message: $message}')
  run run_hook_script "$SCRIPT" "$input"
  decision=$(echo "$output" | jq --raw-output '.decision')
  [ "$decision" = "block" ]
}

@test "recap ignores footer markers that are not at the start of a line" {
  input=$(jq --null-input --arg message "The hook wants 📌 You asked: and 🔗 lines." '{stop_hook_active: false, last_assistant_message: $message}')
  run run_hook_script "$SCRIPT" "$input"
  decision=$(echo "$output" | jq --raw-output '.decision')
  [ "$decision" = "block" ]
}

@test "recap blocks on a Codex Stop payload without a footer" {
  input=$(jq --null-input \
    --arg cwd "$PROJECT_ROOT" \
    '{
      session_id: "session-1",
      transcript_path: null,
      cwd: $cwd,
      hook_event_name: "Stop",
      model: "gpt-5",
      turn_id: "turn-1",
      permission_mode: "default",
      stop_hook_active: false,
      last_assistant_message: "Work done."
    }')

  run "$SCRIPT" <<<"$input"
  [ "$status" -eq 0 ]
  [ "$(jq --raw-output '.decision' <<<"$output")" = "block" ]
}

@test "recap allows stop when stop_hook_active is true" {
  input=$(jq --null-input '{stop_hook_active: true, last_assistant_message: "Work done."}')
  run run_hook_script "$SCRIPT" "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "recap allows stop when last_assistant_message is empty" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: ""}')
  run run_hook_script "$SCRIPT" "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "recap allows stop when RECAP_GUARD is off" {
  input=$(jq --null-input '{stop_hook_active: false, last_assistant_message: "Work done."}')
  RECAP_GUARD=off run run_hook_script "$SCRIPT" "$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
