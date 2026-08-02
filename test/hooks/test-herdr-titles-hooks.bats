#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK_SCRIPT="$PROJECT_ROOT/plugins/herdr-titles/scripts/rename-herdr-tab.sh"
  SESSION_REPORTER_SCRIPT="$PROJECT_ROOT/plugins/herdr-titles/scripts/report-herdr-agent-session.sh"
  CAPTURE_FILE="$BATS_TEST_TMPDIR/herdr-arguments"
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"

  mkdir -p "$MOCK_BIN"
  touch "$CAPTURE_FILE"
  cat >"$MOCK_BIN/herdr" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >"$HERDR_CAPTURE_FILE"
EOF
  chmod +x "$MOCK_BIN/herdr"
}

hook_result() {
  jq --null-input --compact-output \
    --argjson status "$status" \
    --arg output "$output" \
    --rawfile arguments "$CAPTURE_FILE" \
    '{
      status: $status,
      output: $output,
      arguments: ($arguments | split("\n") | map(select(length > 0)))
    }'
}

@test "herdr-titles exposes SessionStart and Stop hooks to Claude only" {
  claude_manifest="$PROJECT_ROOT/plugins/herdr-titles/.claude-plugin/plugin.json"
  codex_manifest="$PROJECT_ROOT/plugins/herdr-titles/.codex-plugin/plugin.json"
  hooks="$PROJECT_ROOT/plugins/herdr-titles/hooks/hooks.json"
  codex_marketplace="$PROJECT_ROOT/.agents/plugins/marketplace.json"

  actual="$(jq --null-input --compact-output \
    --arg claude_hooks "$(jq --raw-output '.hooks' "$claude_manifest")" \
    --arg codex_hooks "$(jq --raw-output '.hooks // empty' "$codex_manifest")" \
    --arg codex_installation "$(jq --raw-output \
      '.plugins[] | select(.name == "herdr-titles") | .policy.installation' \
      "$codex_marketplace")" \
    --arg events "$(jq --raw-output '.hooks | keys | sort | join(",")' "$hooks")" \
    --arg session_start_commands "$(jq --raw-output \
      '.hooks.SessionStart[0].hooks | map(.command) | join(",")' \
      "$hooks")" \
    '{
      claude_hooks: $claude_hooks,
      codex_hooks: $codex_hooks,
      codex_installation: $codex_installation,
      events: $events,
      session_start_commands: $session_start_commands
    }')"

  expected="{\"claude_hooks\":\"./hooks/hooks.json\",\"codex_hooks\":\"\",\"codex_installation\":\"NOT_AVAILABLE\",\"events\":\"SessionStart,Stop\",\"session_start_commands\":\"\${CLAUDE_PLUGIN_ROOT}/scripts/report-herdr-agent-session.sh,\${CLAUDE_PLUGIN_ROOT}/scripts/rename-herdr-tab.sh\"}"
  [ "$actual" = "$expected" ]
}

@test "herdr-titles reports Claude session metadata through the Herdr-managed hook" {
  claude_config_directory="$BATS_TEST_TMPDIR/claude"
  managed_hook="$claude_config_directory/hooks/herdr-agent-state.sh"
  managed_arguments="$BATS_TEST_TMPDIR/managed-arguments"
  managed_input="$BATS_TEST_TMPDIR/managed-input"
  mkdir -p "$claude_config_directory/hooks"
  cat >"$managed_hook" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >"$MANAGED_ARGUMENTS_FILE"
cat >"$MANAGED_INPUT_FILE"
EOF
  chmod +x "$managed_hook"
  input='{"hook_event_name":"SessionStart","session_id":"session-100"}'

  run env \
    CLAUDE_CONFIG_DIR="$claude_config_directory" \
    MANAGED_ARGUMENTS_FILE="$managed_arguments" \
    MANAGED_INPUT_FILE="$managed_input" \
    "$SESSION_REPORTER_SCRIPT" <<<"$input"

  actual="$(jq --null-input --compact-output \
    --argjson status "$status" \
    --rawfile arguments "$managed_arguments" \
    --rawfile input "$managed_input" \
    '{status: $status, arguments: ($arguments | rtrimstr("\n")), input: ($input | rtrimstr("\n"))}')"
  [ "$actual" = '{"status":0,"arguments":"session","input":"{\"hook_event_name\":\"SessionStart\",\"session_id\":\"session-100\"}"}' ]
}

@test "herdr-titles renames the current tab to the latest custom title" {
  transcript="$BATS_TEST_TMPDIR/alice-session.jsonl"
  cat >"$transcript" <<'EOF'
{"type":"custom-title","customTitle":"Alice starts here","sessionId":"session-100"}
{"type":"user","sessionId":"session-100"}
{"type":"custom-title","customTitle":"Alice's \"quoted\" title","sessionId":"session-100"}
EOF
  input="$(jq --null-input --compact-output --arg transcript_path "$transcript" \
    '{transcript_path: $transcript_path}')"

  run env \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    HERDR_TAB_ID="workspace-100:tab-100" \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"","arguments":["tab","rename","workspace-100:tab-100","Alice'"'"'s \"quoted\" title"]}' ]
}

@test "herdr-titles does nothing when the session has no custom title" {
  transcript="$BATS_TEST_TMPDIR/bob-session.jsonl"
  cat >"$transcript" <<'EOF'
{"type":"user","sessionId":"session-200"}
EOF
  input="$(jq --null-input --compact-output --arg transcript_path "$transcript" \
    '{transcript_path: $transcript_path}')"

  run env \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    HERDR_TAB_ID="workspace-200:tab-200" \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"","arguments":[]}' ]
}

@test "herdr-titles does nothing before a new session transcript exists" {
  input="$(jq --null-input --compact-output \
    --arg transcript_path "$BATS_TEST_TMPDIR/missing-session.jsonl" \
    '{transcript_path: $transcript_path}')"

  run env \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    HERDR_TAB_ID="workspace-300:tab-300" \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"","arguments":[]}' ]
}

@test "herdr-titles does nothing outside a Herdr tab" {
  transcript="$BATS_TEST_TMPDIR/charlie-session.jsonl"
  cat >"$transcript" <<'EOF'
{"type":"custom-title","customTitle":"Charlie fixes titles","sessionId":"session-300"}
EOF
  input="$(jq --null-input --compact-output --arg transcript_path "$transcript" \
    '{transcript_path: $transcript_path}')"

  run env -u HERDR_TAB_ID \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"","arguments":[]}' ]
}
