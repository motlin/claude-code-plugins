#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$PROJECT_ROOT/plugins/git-guards/scripts/validate-git.sh"
}

@test "git-guards hooks.json is valid JSON" {
  validate_hooks_json "$PROJECT_ROOT/plugins/git-guards/hooks/hooks.json"
}

@test "git-guards hooks.json has PreToolUse event" {
  hooks=$(jq --raw-output '.hooks | keys | .[]' "$PROJECT_ROOT/plugins/git-guards/hooks/hooks.json")
  [[ "$hooks" =~ "PreToolUse" ]]
}

@test "git-guards hook commands point to existing scripts" {
  all_exist=0
  commands=$(get_hook_commands "$PROJECT_ROOT/plugins/git-guards/hooks/hooks.json" "PreToolUse")
  for cmd in $commands; do
    resolved_cmd=$(echo "$cmd" | sed "s|\${CLAUDE_PLUGIN_ROOT}|$PROJECT_ROOT/plugins/git-guards|g")
    if [ ! -f "$resolved_cmd" ]; then
      echo "Script not found: $resolved_cmd"
      all_exist=1
    fi
  done
  [ "$all_exist" -eq 0 ]
}

@test "git-guards script is executable" {
  [ -x "$SCRIPT" ]
}

@test "git-guards allows normal git commands" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"git status\"}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git-guards allows empty command" {
  run bash -c "echo '{\"tool_input\":{}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- git add -A / --all ---

@test "git-guards denies git add -A" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"git add -A\"}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
}

@test "git-guards denies git add --all" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"git add --all\"}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
}

@test "git-guards allows git add with specific files" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"git add foo.txt bar.txt\"}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- push to main/master ---

@test "git-guards denies push to main" {
  input='{"tool_input":{"command":"git push origin main"}}'
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
  [[ "$output" =~ "feature branch" ]]
}

@test "git-guards denies push to master" {
  input='{"tool_input":{"command":"git push origin master"}}'
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
}

@test "git-guards denies force push to main" {
  input='{"tool_input":{"command":"git push --force origin main"}}'
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
}

@test "git-guards allows push to feature branch" {
  input='{"tool_input":{"command":"git push origin feature-branch"}}'
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git-guards allows push with -u to feature branch" {
  input='{"tool_input":{"command":"git push -u origin my-feature"}}'
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- force push without --force-with-lease ---

@test "git-guards denies --force on feature branch" {
  input='{"tool_input":{"command":"git push --force origin feature"}}'
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
  [[ "$output" =~ "force-with-lease" ]]
}

@test "git-guards denies -f on feature branch" {
  input='{"tool_input":{"command":"git push -f origin feature"}}'
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
  [[ "$output" =~ "force-with-lease" ]]
}

@test "git-guards allows --force-with-lease on feature branch" {
  input='{"tool_input":{"command":"git push --force-with-lease origin feature"}}'
  run bash -c "echo '$input' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- git reset --hard ---

@test "git-guards denies git reset --hard" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"git reset --hard HEAD~1\"}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
}

# --- git clean -fd ---

@test "git-guards denies git clean -fd" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"git clean -fd\"}}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  decision=$(echo "$output" | jq --raw-output '.hookSpecificOutput.permissionDecision')
  [ "$decision" = "deny" ]
}
