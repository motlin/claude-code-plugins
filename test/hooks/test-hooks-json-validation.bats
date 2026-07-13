#!/usr/bin/env bats

setup() {
  load '../lib/hook-helpers.sh'
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "terminal title hook files are valid JSON" {
  for plugin in tmux-titles iterm2-titles ghostty-titles; do
    validate_hooks_json "$PROJECT_ROOT/plugins/$plugin/hooks/hooks.json"
    validate_hooks_json "$PROJECT_ROOT/plugins/$plugin/hooks/claude-hooks.json"
  done
}

@test "default terminal title hooks use only the shared Codex event subset" {
  expected="PostToolUse,PreCompact,PreToolUse,SessionStart,Stop,UserPromptSubmit,"

  for plugin in tmux-titles iterm2-titles ghostty-titles; do
    hooks=$(jq --raw-output '.hooks | keys[]' \
      "$PROJECT_ROOT/plugins/$plugin/hooks/hooks.json" | sort | tr '\n' ',')
    [ "$hooks" = "$expected" ]
  done
}

@test "Claude manifests load the richer terminal title hook configs" {
  for plugin in tmux-titles iterm2-titles ghostty-titles; do
    manifest="$PROJECT_ROOT/plugins/$plugin/.claude-plugin/plugin.json"
    [ "$(jq --raw-output '.hooks' "$manifest")" = "./hooks/claude-hooks.json" ]
    jq --exit-status '.hooks.Notification' \
      "$PROJECT_ROOT/plugins/$plugin/hooks/claude-hooks.json" >/dev/null
  done

  jq --exit-status '.hooks.SessionEnd' \
    "$PROJECT_ROOT/plugins/tmux-titles/hooks/claude-hooks.json" >/dev/null
}

@test "terminal title hooks use command type consistently" {
  check_hook_type_consistency \
    "$PROJECT_ROOT/plugins/tmux-titles/hooks/hooks.json" \
    "$PROJECT_ROOT/plugins/tmux-titles/scripts/update-tmux-title.sh"
  check_hook_type_consistency \
    "$PROJECT_ROOT/plugins/iterm2-titles/hooks/hooks.json" \
    "$PROJECT_ROOT/plugins/iterm2-titles/scripts/update-title.sh"
  check_hook_type_consistency \
    "$PROJECT_ROOT/plugins/ghostty-titles/hooks/hooks.json" \
    "$PROJECT_ROOT/plugins/ghostty-titles/scripts/update-title.sh"
}

@test "all terminal title hook commands point to existing scripts" {
  for plugin in tmux-titles iterm2-titles ghostty-titles; do
    for hooks_file in hooks.json claude-hooks.json; do
      while IFS= read -r command; do
        script_name="${command#*\/scripts\/}"
        script_name="${script_name%% *}"
        [ -f "$PROJECT_ROOT/plugins/$plugin/scripts/$script_name" ]
      done < <(jq --raw-output '.hooks[][]?.hooks[]?.command // empty' \
        "$PROJECT_ROOT/plugins/$plugin/hooks/$hooks_file")
    done
  done
}

@test "Ghostty tool hook accepts Codex tool and cwd fields" {
  mock_bin="$BATS_TEST_TMPDIR/ghostty-bin"
  mkdir -p "$mock_bin"
  cat >"$mock_bin/ps" <<'EOF'
#!/bin/bash
echo null
EOF
  chmod +x "$mock_bin/ps"
  test_json=$(create_codex_test_json "/home/user/projects/codex-app" "Bash")
  run env PATH="$mock_bin:$PATH" TERM_PROGRAM="ghostty" \
    bash -c "echo '$test_json' | '$PROJECT_ROOT/plugins/ghostty-titles/scripts/update-for-tool-hook.sh'"
  [ "$status" -eq 0 ]
}
