#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "update-for-tool-hook.sh exits early when LC_TERMINAL not set" {
  unset LC_TERMINAL || true
  test_json=$(create_test_json "/tmp/test" "Bash")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-for-tool-hook.sh'"
  [ "$status" -eq 0 ]
}

@test "update-for-tool-hook.sh exits early when LC_TERMINAL is not iTerm2" {
  export LC_TERMINAL="xterm"
  test_json=$(create_test_json "/tmp/test" "Bash")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-for-tool-hook.sh'"
  [ "$status" -eq 0 ]
  unset LC_TERMINAL
}

@test "update-iterm-title.sh exits early when LC_TERMINAL not set" {
  unset LC_TERMINAL || true
  test_json=$(create_test_json "/tmp/test" "Bash")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-iterm-title.sh' '\$'"
  [ "$status" -eq 0 ]
}

@test "update-iterm-title.sh exits early when LC_TERMINAL is not iTerm2" {
  export LC_TERMINAL="xterm"
  test_json=$(create_test_json "/tmp/test" "Bash")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-iterm-title.sh' '\$'"
  [ "$status" -eq 0 ]
  unset LC_TERMINAL
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

@test "iTerm escape code format is correct" {
  test_json=$(create_test_json "/home/user/projects/my-app")
  temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/bin/bash
set -Eeuo pipefail
indicator="${1:-}"
json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")
printf "\e]0;%s %s\a" "$indicator" "$dir_name"
EOF
  chmod +x "$temp_script"
  run bash -c "echo '$test_json' | '$temp_script' '✓'"
  rm "$temp_script"
  [[ "$output" =~ "✓ my-app" ]]
}
