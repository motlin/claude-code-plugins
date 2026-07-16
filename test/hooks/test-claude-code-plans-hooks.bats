#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  mock_bin="$BATS_TEST_TMPDIR/bin"
  capture_file="$BATS_TEST_TMPDIR/curl-arguments"
  mkdir -p "$mock_bin"
  cat >"$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$CURL_CAPTURE_FILE"
EOF
  chmod +x "$mock_bin/curl"
}

captured_payload() {
  awk 'previous == "-d" { print; exit } { previous = $0 }' "$capture_file"
}

@test "Codex hooks use the supported lifecycle subset" {
  hooks="$(jq --raw-output '.hooks | keys[]' \
    "$PROJECT_ROOT/plugins/claude-code-plans/hooks/hooks.json" | sort | tr '\n' ',')"
  [ "$hooks" = "PostToolUse,SessionStart,Stop," ]
}

@test "Claude manifest loads the complete lifecycle hook set" {
  manifest="$PROJECT_ROOT/plugins/claude-code-plans/.claude-plugin/plugin.json"
  hooks="$PROJECT_ROOT/plugins/claude-code-plans/hooks/claude-hooks.json"
  [ "$(jq --raw-output '.hooks' "$manifest")" = "./hooks/claude-hooks.json" ]
  jq --exit-status '.hooks.SessionEnd and .hooks.TaskCompleted and .hooks.WorktreeCreate' \
    "$hooks" >/dev/null
}

@test "SessionStart forwards Codex hook payload fields" {
  input="$(jq --null-input '{
    session_id: "codex-test-session",
    hook_event_name: "SessionStart",
    cwd: "/test/project",
    model: "test-model"
  }')"

  run env PATH="$mock_bin:$PATH" CURL_CAPTURE_FILE="$capture_file" \
    "$PROJECT_ROOT/plugins/claude-code-plans/scripts/post-hook.sh" SessionStart <<<"$input"
  [ "$status" -eq 0 ]
  payload="$(captured_payload)"
  [ "$(jq --raw-output '.session_id' <<<"$payload")" = "codex-test-session" ]
  [ "$(jq --raw-output '.hook_event_name' <<<"$payload")" = "SessionStart" ]
  [ "$(jq --raw-output '.cwd' <<<"$payload")" = "/test/project" ]
  [ "$(jq --raw-output '.model' <<<"$payload")" = "test-model" ]
}

@test "PostToolUse forwards the Codex tool name" {
  input="$(jq --null-input '{
    session_id: "codex-test-session",
    hook_event_name: "PostToolUse",
    tool_name: "Bash"
  }')"

  run env PATH="$mock_bin:$PATH" CURL_CAPTURE_FILE="$capture_file" \
    "$PROJECT_ROOT/plugins/claude-code-plans/scripts/post-hook.sh" PostToolUse <<<"$input"
  [ "$status" -eq 0 ]
  payload="$(captured_payload)"
  [ "$(jq --raw-output '.tool_name' <<<"$payload")" = "Bash" ]
}
