#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "worktree-setup hooks.json is valid JSON" {
  validate_hooks_json "$PROJECT_ROOT/plugins/worktree-setup/hooks/hooks.json"
}

@test "worktree-setup hooks.json has WorktreeCreate event" {
  hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/worktree-setup/hooks/hooks.json")
  [[ "$hooks" =~ "WorktreeCreate" ]]
}

@test "worktree-setup hook commands point to existing scripts" {
  all_exist=0
  commands=$(get_hook_commands "$PROJECT_ROOT/plugins/worktree-setup/hooks/hooks.json" "WorktreeCreate")
  for command in $commands; do
    resolved_command="${command//\$\{CLAUDE_PLUGIN_ROOT\}/$PROJECT_ROOT/plugins/worktree-setup}"
    if [ ! -f "$resolved_command" ]; then
      echo "Script not found: $resolved_command"
      all_exist=1
    fi
  done
  [ "$all_exist" -eq 0 ]
}

@test "worktree-setup hooks use command type" {
  hook_type=$(jq --raw-output '.hooks.WorktreeCreate[0].hooks[0].type' "$PROJECT_ROOT/plugins/worktree-setup/hooks/hooks.json")
  [ "$hook_type" = "command" ]
}
