#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK_SCRIPT="$PROJECT_ROOT/plugins/herdr-titles/scripts/sync-claude-title-from-herdr.sh"
  SESSION_REPORTER_SCRIPT="$PROJECT_ROOT/plugins/herdr-titles/scripts/report-herdr-agent-session.sh"
  CAPTURE_FILE="$BATS_TEST_TMPDIR/herdr-arguments"
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"

  mkdir -p "$MOCK_BIN"
  touch "$CAPTURE_FILE"
  cat >"$MOCK_BIN/herdr" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >"$HERDR_CAPTURE_FILE"
if [ -n "${HERDR_FAIL:-}" ]; then
  exit 1
fi
jq --null-input --compact-output --arg tab_id "$3" --arg label "$HERDR_TAB_LABEL" \
  '{id: "cli:tab:get", result: {tab: {tab_id: $tab_id, label: $label}, type: "tab_info"}}'
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

@test "herdr-titles exposes SessionStart and UserPromptSubmit hooks to Claude only through the auto-loaded hooks file" {
  claude_manifest="$PROJECT_ROOT/plugins/herdr-titles/.claude-plugin/plugin.json"
  codex_manifest="$PROJECT_ROOT/plugins/herdr-titles/.codex-plugin/plugin.json"
  hooks="$PROJECT_ROOT/plugins/herdr-titles/hooks/hooks.json"
  codex_marketplace="$PROJECT_ROOT/.agents/plugins/marketplace.json"

  actual="$(jq --null-input --compact-output \
    --arg claude_hooks "$(jq --raw-output '.hooks // empty' "$claude_manifest")" \
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

  expected="{\"claude_hooks\":\"\",\"codex_hooks\":\"\",\"codex_installation\":\"NOT_AVAILABLE\",\"events\":\"SessionStart,UserPromptSubmit\",\"session_start_commands\":\"\\\"\${CLAUDE_PLUGIN_ROOT}/scripts/report-herdr-agent-session.sh\\\",\\\"\${CLAUDE_PLUGIN_ROOT}/scripts/sync-claude-title-from-herdr.sh\\\"\"}"
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

@test "herdr-titles copies the Herdr tab label into the Claude session title" {
  input='{"hook_event_name":"UserPromptSubmit","session_id":"session-100"}'

  run env \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    HERDR_TAB_ID="workspace-100:tab-100" \
    HERDR_TAB_LABEL="Alice's \"quoted\" title" \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"sessionTitle\":\"Alice'"'"'s \\\"quoted\\\" title\"}}","arguments":["tab","get","workspace-100:tab-100"]}' ]
}

@test "herdr-titles sets the Claude session title when a session starts" {
  input='{"hook_event_name":"SessionStart","session_id":"session-200"}'

  run env \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    HERDR_TAB_ID="workspace-200:tab-200" \
    HERDR_TAB_LABEL="Bob reviews PRs" \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"sessionTitle\":\"Bob reviews PRs\"}}","arguments":["tab","get","workspace-200:tab-200"]}' ]
}

@test "herdr-titles ignores Herdr's default numeric tab labels" {
  input='{"hook_event_name":"UserPromptSubmit","session_id":"session-300"}'

  run env \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    HERDR_TAB_ID="workspace-300:tab-300" \
    HERDR_TAB_LABEL="12" \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"","arguments":["tab","get","workspace-300:tab-300"]}' ]
}

@test "herdr-titles does nothing when Herdr cannot report the tab" {
  input='{"hook_event_name":"UserPromptSubmit","session_id":"session-400"}'

  run env \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    HERDR_TAB_ID="workspace-400:tab-400" \
    HERDR_FAIL=1 \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"","arguments":["tab","get","workspace-400:tab-400"]}' ]
}

@test "herdr-titles does nothing outside a Herdr tab" {
  input='{"hook_event_name":"UserPromptSubmit","session_id":"session-500"}'

  run env -u HERDR_TAB_ID \
    PATH="$MOCK_BIN:$PATH" \
    HERDR_CAPTURE_FILE="$CAPTURE_FILE" \
    HERDR_TAB_LABEL="Charlie fixes titles" \
    "$HOOK_SCRIPT" <<<"$input"

  [ "$(hook_result)" = '{"status":0,"output":"","arguments":[]}' ]
}
