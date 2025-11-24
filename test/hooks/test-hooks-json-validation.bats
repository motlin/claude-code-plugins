#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "tmux-titles hooks.json is valid JSON" {
  validate_hooks_json "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json"
}

@test "iterm2-titles hooks.json is valid JSON" {
  validate_hooks_json "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json"
}

@test "tmux-titles hooks.json has expected event types" {
  hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json" | sort | tr '\n' ',')
  [[ "$hooks" =~ "UserPromptSubmit" ]]
  [[ "$hooks" =~ "Stop" ]]
  [[ "$hooks" =~ "SessionStart" ]]
  [[ "$hooks" =~ "PreToolUse" ]]
  [[ "$hooks" =~ "PostToolUse" ]]
}

@test "iterm2-titles hooks.json has expected event types" {
  hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json" | sort | tr '\n' ',')
  [[ "$hooks" =~ "UserPromptSubmit" ]]
  [[ "$hooks" =~ "Stop" ]]
  [[ "$hooks" =~ "SessionStart" ]]
  [[ "$hooks" =~ "PreToolUse" ]]
  [[ "$hooks" =~ "PostToolUse" ]]
}

@test "tmux-titles hooks use command type correctly" {
  check_hook_type_consistency "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json" "update-tmux-title.sh"
}

@test "iterm2-titles hooks use command type correctly" {
  check_hook_type_consistency "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json" "update-iterm-title.sh"
}

@test "all tmux-titles hook commands point to existing scripts" {
  all_exist=0
  commands=$(get_hook_commands "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json" "PreToolUse")
  for cmd in $commands; do
    script_name=$(echo "$cmd" | sed 's/.*\///')
    if [ ! -f "$PROJECT_ROOT/plugins/tmux-titles/scripts/$script_name" ]; then
      all_exist=1
    fi
  done
  [ "$all_exist" -eq 0 ]
}

@test "all iterm2-titles hook commands point to existing scripts" {
  all_exist=0
  commands=$(get_hook_commands "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json" "PreToolUse")
  for cmd in $commands; do
    script_name=$(echo "$cmd" | sed 's/.*\///')
    if [ ! -f "$PROJECT_ROOT/plugins/iterm2-titles/scripts/$script_name" ]; then
      all_exist=1
    fi
  done
  [ "$all_exist" -eq 0 ]
}
