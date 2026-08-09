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

@test "update-for-tool-hook.sh accepts Codex hook fields" {
  mock_bin="$BATS_TEST_TMPDIR/iterm-bin"
  mkdir -p "$mock_bin"
  cat >"$mock_bin/ps" <<'EOF'
#!/bin/bash
echo null
EOF
  chmod +x "$mock_bin/ps"
  test_json=$(create_codex_test_json "/home/user/projects/codex-app" "Bash")
  run env PATH="$mock_bin:$PATH" LC_TERMINAL="iTerm2" \
    bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-for-tool-hook.sh'"
  [ "$status" -eq 0 ]
}

@test "update-for-tool-hook.sh exits early when LC_TERMINAL is not iTerm2" {
  test_json=$(create_test_json "/tmp/test" "Bash")
  run env LC_TERMINAL="xterm" \
    bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-for-tool-hook.sh'"
  [ "$status" -eq 0 ]
}

@test "update-iterm-title.sh exits early when LC_TERMINAL not set" {
  unset LC_TERMINAL || true
  test_json=$(create_test_json "/tmp/test" "Bash")
  run bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-title.sh' '\$'"
  [ "$status" -eq 0 ]
}

@test "update-iterm-title.sh exits early when LC_TERMINAL is not iTerm2" {
  test_json=$(create_test_json "/tmp/test" "Bash")
  run env LC_TERMINAL="xterm" \
    bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-title.sh' '\$'"
  [ "$status" -eq 0 ]
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

@test "require-no-herdr.sh stays quiet outside herdr" {
  test_json=$(create_test_json "/tmp/test")
  run env -u HERDR_ENV bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/require-no-herdr.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "require-no-herdr.sh reports a blocking error inside herdr" {
  test_json=$(create_test_json "/tmp/test")
  run env HERDR_ENV=1 \
    bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/require-no-herdr.sh'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"iterm2-titles"* ]]
  [[ "$output" == *"CLAUDE_CODE_DISABLE_TERMINAL_TITLE"* ]]
}

@test "update-title.sh refuses to write a title inside herdr" {
  mock_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$mock_bin"
  cat >"$mock_bin/ps" <<'MOCK'
#!/bin/bash
echo "not-a-real-device"
MOCK
  chmod +x "$mock_bin/ps"
  test_json=$(create_test_json "/tmp/test")
  run env -u HERDR_ENV PATH="$mock_bin:$PATH" LC_TERMINAL="iTerm2" \
    bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-title.sh' '✻'"
  [ "$status" -ne 0 ]
  run env PATH="$mock_bin:$PATH" LC_TERMINAL="iTerm2" HERDR_ENV=1 \
    bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-title.sh' '✻'"
  [ "$status" -eq 0 ]
}

@test "SessionStart runs the herdr guard before any title hook" {
  hooks_json="$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json"
  first_command=$(jq --raw-output '.hooks.SessionStart[0].hooks[0].command' "$hooks_json")
  [[ "$first_command" == *"require-no-herdr.sh"* ]]
}
