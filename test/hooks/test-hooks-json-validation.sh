#!/bin/bash

set -Eeuo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/test-framework.sh"
source "$script_dir/../lib/hook-helpers.sh"

PROJECT_ROOT="$(command cd "$script_dir/../.." && pwd)"

test "tmux-titles hooks.json is valid JSON"
if validate_hooks_json "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json"; then
  assert_exit_code 0 0
else
  assert_exit_code 0 1
fi

test "iterm2-titles hooks.json is valid JSON"
if validate_hooks_json "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json"; then
  assert_exit_code 0 0
else
  assert_exit_code 0 1
fi

test "tmux-titles hooks.json has expected event types"
hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json" | sort | tr '\n' ',')
assert_contains "$hooks" "UserPromptSubmit"
assert_contains "$hooks" "Stop"
assert_contains "$hooks" "SessionStart"
assert_contains "$hooks" "PreToolUse"
assert_contains "$hooks" "PostToolUse"

test "iterm2-titles hooks.json has expected event types"
hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json" | sort | tr '\n' ',')
assert_contains "$hooks" "UserPromptSubmit"
assert_contains "$hooks" "Stop"
assert_contains "$hooks" "SessionStart"
assert_contains "$hooks" "PreToolUse"
assert_contains "$hooks" "PostToolUse"

test "tmux-titles hooks use command type correctly"
if check_hook_type_consistency "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json" "update-tmux-title.sh"; then
  assert_exit_code 0 0
else
  assert_exit_code 0 1
fi

test "iterm2-titles hooks use command type correctly"
if check_hook_type_consistency "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json" "update-iterm-title.sh"; then
  assert_exit_code 0 0
else
  assert_exit_code 0 1
fi

test "all tmux-titles hook commands point to existing scripts"
all_exist=0
commands=$(get_hook_commands "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json" "PreToolUse")
for cmd in $commands; do
  script_name=$(echo "$cmd" | sed 's/.*\///')
  if [ ! -f "$PROJECT_ROOT/plugins/tmux-titles/scripts/$script_name" ]; then
    all_exist=1
  fi
done
assert_exit_code 0 $all_exist

test "all iterm2-titles hook commands point to existing scripts"
all_exist=0
commands=$(get_hook_commands "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json" "PreToolUse")
for cmd in $commands; do
  script_name=$(echo "$cmd" | sed 's/.*\///')
  if [ ! -f "$PROJECT_ROOT/plugins/iterm2-titles/scripts/$script_name" ]; then
    all_exist=1
  fi
done
assert_exit_code 0 $all_exist

exit $TESTS_FAILED
