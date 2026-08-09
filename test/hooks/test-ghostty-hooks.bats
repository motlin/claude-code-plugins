#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GHOSTTY_SCRIPTS="$PROJECT_ROOT/plugins/ghostty-titles/scripts"
}

# Mocks ps so the title scripts resolve a tty that cannot be written to, which
# separates "refused to run" (status 0) from "tried to write a title" (nonzero).
function mock_unwritable_tty() {
  mock_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$mock_bin"
  cat >"$mock_bin/ps" <<'EOF'
#!/bin/bash
echo "not-a-real-device"
EOF
  chmod +x "$mock_bin/ps"
  echo "$mock_bin"
}

@test "require-no-herdr.sh stays quiet outside herdr" {
  test_json=$(create_test_json "/tmp/test")
  run env -u HERDR_ENV bash -c "echo '$test_json' | '$GHOSTTY_SCRIPTS/require-no-herdr.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "require-no-herdr.sh reports a blocking error inside herdr" {
  test_json=$(create_test_json "/tmp/test")
  run env HERDR_ENV=1 \
    bash -c "echo '$test_json' | '$GHOSTTY_SCRIPTS/require-no-herdr.sh'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"ghostty-titles"* ]]
  [[ "$output" == *"herdr"* ]]
  [[ "$output" == *"CLAUDE_CODE_DISABLE_TERMINAL_TITLE"* ]]
}

@test "update-title.sh writes a title outside herdr" {
  mock_bin="$(mock_unwritable_tty)"
  test_json=$(create_test_json "/tmp/test")
  run env -u HERDR_ENV PATH="$mock_bin:$PATH" TERM_PROGRAM=ghostty \
    bash -c "echo '$test_json' | '$GHOSTTY_SCRIPTS/update-title.sh' '✻'"
  [ "$status" -ne 0 ]
}

@test "update-title.sh refuses to write a title inside herdr" {
  mock_bin="$(mock_unwritable_tty)"
  test_json=$(create_test_json "/tmp/test")
  run env PATH="$mock_bin:$PATH" TERM_PROGRAM=ghostty HERDR_ENV=1 \
    bash -c "echo '$test_json' | '$GHOSTTY_SCRIPTS/update-title.sh' '✻'"
  [ "$status" -eq 0 ]
}

@test "update-for-tool-hook.sh refuses to write a title inside herdr" {
  mock_bin="$(mock_unwritable_tty)"
  test_json=$(create_test_json "/tmp/test" "Bash")
  run env PATH="$mock_bin:$PATH" TERM_PROGRAM=ghostty HERDR_ENV=1 \
    bash -c "echo '$test_json' | '$GHOSTTY_SCRIPTS/update-for-tool-hook.sh'"
  [ "$status" -eq 0 ]
}

@test "SessionStart runs the herdr guard before any title hook" {
  hooks_json="$PROJECT_ROOT/plugins/ghostty-titles/hooks/hooks.json"
  first_command=$(jq --raw-output '.hooks.SessionStart[0].hooks[0].command' "$hooks_json")
  [[ "$first_command" == *"require-no-herdr.sh"* ]]
}
