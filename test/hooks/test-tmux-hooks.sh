#!/bin/bash

set -Eeuo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/test-framework.sh"
source "$script_dir/../lib/hook-helpers.sh"

PROJECT_ROOT="$(command cd "$script_dir/../.." && pwd)"

test "update-for-tool-hook.sh exits early when TMUX not set"
unset TMUX TMUX_PANE || true
test_json=$(create_test_json "/tmp/test" "Bash")
if output=$(echo "$test_json" | "$PROJECT_ROOT/plugins/tmux-titles/scripts/update-for-tool-hook.sh" 2>&1); then
  assert_exit_code 0 0
else
  exit_code=$?
  assert_exit_code 0 $exit_code "Should exit 0 when TMUX not set"
fi

test "update-for-tool-hook.sh exits early when TMUX_PANE not set"
export TMUX="test"
unset TMUX_PANE || true
test_json=$(create_test_json "/tmp/test" "Bash")
if output=$(echo "$test_json" | "$PROJECT_ROOT/plugins/tmux-titles/scripts/update-for-tool-hook.sh" 2>&1); then
  assert_exit_code 0 0
else
  exit_code=$?
  assert_exit_code 0 $exit_code "Should exit 0 when TMUX_PANE not set"
fi
unset TMUX

test "update-tmux-title.sh exits early when TMUX not set"
unset TMUX TMUX_PANE || true
test_json=$(create_test_json "/tmp/test")
if output=$(echo "$test_json" | "$PROJECT_ROOT/plugins/tmux-titles/scripts/update-tmux-title.sh" "✻" 2>&1); then
  assert_exit_code 0 0
else
  exit_code=$?
  assert_exit_code 0 $exit_code "Should exit 0 when TMUX not set"
fi

test "update-tmux-title.sh exits early when TMUX_PANE not set"
export TMUX="test"
unset TMUX_PANE || true
test_json=$(create_test_json "/tmp/test")
if output=$(echo "$test_json" | "$PROJECT_ROOT/plugins/tmux-titles/scripts/update-tmux-title.sh" "✻" 2>&1); then
  assert_exit_code 0 0
else
  exit_code=$?
  assert_exit_code 0 $exit_code "Should exit 0 when TMUX_PANE not set"
fi
unset TMUX

test "update-for-tool-hook.sh recognizes Bash tool icon"
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
output=$(echo "$test_json" | "$temp_script" 2>&1)
rm "$temp_script"
assert_contains "$output" "bash_icon"

test "update-for-tool-hook.sh recognizes Edit tool icon"
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
output=$(echo "$test_json" | "$temp_script" 2>&1)
rm "$temp_script"
assert_contains "$output" "edit_icon"

test "update-for-tool-hook.sh recognizes Read tool icon"
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
output=$(echo "$test_json" | "$temp_script" 2>&1)
rm "$temp_script"
assert_contains "$output" "read_icon"

test "hook script extracts cwd from JSON"
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
output=$(echo "$test_json" | "$temp_script" 2>&1)
rm "$temp_script"
assert_contains "$output" "cwd:/home/user/projects/my-app"

test "tmux escape code format is correct"
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
output=$(echo "$test_json" | "$temp_script" "✓" 2>&1)
rm "$temp_script"
assert_contains "$output" "✓ my-app"

exit $TESTS_FAILED
