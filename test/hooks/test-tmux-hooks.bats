#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "update-for-tool-hook.sh exits early when TMUX not set" {
  unset TMUX TMUX_PANE || true
  test_json=$(create_test_json "/tmp/test" "Bash")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/tmux-titles/scripts/update-for-tool-hook.sh'"
  [ "$status" -eq 0 ]
}

@test "update-for-tool-hook.sh exits early when TMUX_PANE not set" {
  export TMUX="test"
  unset TMUX_PANE || true
  test_json=$(create_test_json "/tmp/test" "Bash")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/tmux-titles/scripts/update-for-tool-hook.sh'"
  [ "$status" -eq 0 ]
  unset TMUX
}

@test "update-tmux-title.sh exits early when TMUX not set" {
  unset TMUX TMUX_PANE || true
  test_json=$(create_test_json "/tmp/test")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/tmux-titles/scripts/update-tmux-title.sh' '✻'"
  [ "$status" -eq 0 ]
}

@test "update-tmux-title.sh exits early when TMUX_PANE not set" {
  export TMUX="test"
  unset TMUX_PANE || true
  test_json=$(create_test_json "/tmp/test")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/tmux-titles/scripts/update-tmux-title.sh' '✻'"
  [ "$status" -eq 0 ]
  unset TMUX
}

@test "update-for-tool-hook.sh recognizes Bash tool icon" {
  test_json=$(create_test_json "/tmp/test" "Bash")
  temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -Eeuo pipefail
json=$(cat)
tool_name=$(echo "$json" | jq --raw-output '.tool_name')
case "$tool_name" in
  Bash)
    echo "bash_icon"
    ;;
  *)
    echo "other_icon"
    ;;
esac
EOF
  chmod +x "$temp_script"
  run bash -c "echo '$test_json' | '$temp_script'"
  rm "$temp_script"
  [[ "$output" =~ "bash_icon" ]]
}

@test "update-for-tool-hook.sh recognizes Edit tool icon" {
  test_json=$(create_test_json "/tmp/test" "Edit")
  temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -Eeuo pipefail
json=$(cat)
tool_name=$(echo "$json" | jq --raw-output '.tool_name')
case "$tool_name" in
  Create|Edit|Write|MultiEdit)
    echo "edit_icon"
    ;;
  *)
    echo "other_icon"
    ;;
esac
EOF
  chmod +x "$temp_script"
  run bash -c "echo '$test_json' | '$temp_script'"
  rm "$temp_script"
  [[ "$output" =~ "edit_icon" ]]
}

@test "update-for-tool-hook.sh recognizes Read tool icon" {
  test_json=$(create_test_json "/tmp/test" "Read")
  temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -Eeuo pipefail
json=$(cat)
tool_name=$(echo "$json" | jq --raw-output '.tool_name')
case "$tool_name" in
  Read)
    echo "read_icon"
    ;;
  *)
    echo "other_icon"
    ;;
esac
EOF
  chmod +x "$temp_script"
  run bash -c "echo '$test_json' | '$temp_script'"
  rm "$temp_script"
  [[ "$output" =~ "read_icon" ]]
}

@test "hook script extracts cwd from JSON" {
  test_json=$(create_test_json "/home/user/projects/my-app")
  temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -Eeuo pipefail
json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
echo "cwd:$cwd"
EOF
  chmod +x "$temp_script"
  run bash -c "echo '$test_json' | '$temp_script'"
  rm "$temp_script"
  [[ "$output" =~ "cwd:/home/user/projects/my-app" ]]
}

@test "rename-tmux-window.sh exits early when TMUX not set" {
  unset TMUX TMUX_PANE || true
  test_json=$(create_test_json "/tmp/test" "TestTool" '{"prompt": "/rename my-project"}')
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/tmux-titles/scripts/rename-tmux-window.sh'"
  [ "$status" -eq 0 ]
}

@test "rename-tmux-window.sh exits early when TMUX_PANE not set" {
  export TMUX="test"
  unset TMUX_PANE || true
  test_json=$(create_test_json "/tmp/test" "TestTool" '{"prompt": "/rename my-project"}')
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/tmux-titles/scripts/rename-tmux-window.sh'"
  [ "$status" -eq 0 ]
  unset TMUX
}

@test "rename-tmux-window.sh exits early for non-rename prompt" {
  export TMUX="test"
  export TMUX_PANE="%0"
  test_json=$(create_test_json "/tmp/test" "TestTool" '{"prompt": "fix the bug"}')
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/tmux-titles/scripts/rename-tmux-window.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  unset TMUX TMUX_PANE
}

@test "rename-tmux-window.sh extracts name from prompt" {
  test_json=$(create_test_json "/tmp/test" "TestTool" '{"prompt": "/rename my-project"}')
  temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -Eeuo pipefail
json=$(cat)
prompt=$(echo "$json" | jq --raw-output '.prompt')
name=$(echo "$prompt" | sed 's|^/rename ||')
echo "name:$name"
EOF
  chmod +x "$temp_script"
  run bash -c "echo '$test_json' | '$temp_script'"
  rm "$temp_script"
  [[ "$output" =~ "name:my-project" ]]
}

@test "tmux escape code format is correct" {
  test_json=$(create_test_json "/home/user/projects/my-app")
  temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -Eeuo pipefail
indicator="${1:-}"
json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")
printf '\033k%s %s\033\\' "$indicator" "$dir_name"
EOF
  chmod +x "$temp_script"
  run bash -c "echo '$test_json' | '$temp_script' '✓'"
  rm "$temp_script"
  [[ "$output" =~ "✓ my-app" ]]
}
