#!/usr/bin/env bats

# Every `${CLAUDE_PLUGIN_ROOT}` here is fixture text the check is supposed to
# match literally, so the unexpanded single quotes are the point.
# shellcheck disable=SC2016

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=test/lib/codex-plugin-helpers.sh
  source "$PROJECT_ROOT/test/lib/codex-plugin-helpers.sh"

  PLUGIN_ROOT="$BATS_TEST_TMPDIR/plugin"
  mkdir -p "$PLUGIN_ROOT/scripts" "$PLUGIN_ROOT/bin" "$PLUGIN_ROOT/hooks"
  touch "$PLUGIN_ROOT/scripts/present.sh" "$PLUGIN_ROOT/bin/present.sh"
  SOURCE_FILE="$PLUGIN_ROOT/hooks/hooks.json"
}

@test "references resolving to existing files report nothing" {
  cat >"$SOURCE_FILE" <<'JSON'
{"a": "${CLAUDE_PLUGIN_ROOT}/scripts/present.sh", "b": "<plugin-root>/scripts/present.sh"}
JSON

  run missing_plugin_script_references "$PLUGIN_ROOT" "$SOURCE_FILE"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "a missing script under scripts/ is reported" {
  printf '%s\n' '${CLAUDE_PLUGIN_ROOT}/scripts/absent.sh' >"$SOURCE_FILE"

  run missing_plugin_script_references "$PLUGIN_ROOT" "$SOURCE_FILE"

  [ "$status" -eq 0 ]
  [ "$output" = "$SOURCE_FILE: \${CLAUDE_PLUGIN_ROOT}/scripts/absent.sh" ]
}

# The check used to match only paths under `scripts/`, so a hook pointing at a
# deleted file in any other directory read as "no broken references".
@test "a missing file outside scripts/ is reported" {
  printf '%s\n' '${CLAUDE_PLUGIN_ROOT}/bin/absent.sh' >"$SOURCE_FILE"

  run missing_plugin_script_references "$PLUGIN_ROOT" "$SOURCE_FILE"

  [ "$status" -eq 0 ]
  [ "$output" = "$SOURCE_FILE: \${CLAUDE_PLUGIN_ROOT}/bin/absent.sh" ]
}

@test "an existing file outside scripts/ reports nothing" {
  printf '%s\n' '${CLAUDE_PLUGIN_ROOT}/bin/present.sh' >"$SOURCE_FILE"

  run missing_plugin_script_references "$PLUGIN_ROOT" "$SOURCE_FILE"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "every plugin-root spelling resolves the same relative path" {
  printf '%s\n' \
    '$CLAUDE_PLUGIN_ROOT/bin/absent.sh' \
    '${CLAUDE_PLUGIN_ROOT}/bin/absent.sh' \
    '<plugin-root>/bin/absent.sh' >"$SOURCE_FILE"

  run missing_plugin_script_references "$PLUGIN_ROOT" "$SOURCE_FILE"

  # The extraction sorts its matches, and where `$`, `{`, and `<` land relative
  # to each other depends on the locale, so this asserts membership not order.
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  grep --fixed-strings --quiet -- "$SOURCE_FILE: \$CLAUDE_PLUGIN_ROOT/bin/absent.sh" <<<"$output"
  grep --fixed-strings --quiet -- "$SOURCE_FILE: \${CLAUDE_PLUGIN_ROOT}/bin/absent.sh" <<<"$output"
  grep --fixed-strings --quiet -- "$SOURCE_FILE: <plugin-root>/bin/absent.sh" <<<"$output"
}

# A missing ripgrep makes the extraction silently return nothing, which every
# caller reads as a clean result.
@test "a missing rg fails instead of reporting a clean result" {
  empty_path="$BATS_TEST_TMPDIR/empty-bin"
  mkdir -p "$empty_path"
  printf '%s\n' '${CLAUDE_PLUGIN_ROOT}/scripts/absent.sh' >"$SOURCE_FILE"

  run env PATH="$empty_path" "$BASH" -c '
    source "$1"
    extract_literal_plugin_script_references "$2"
  ' _ "$PROJECT_ROOT/test/lib/codex-plugin-helpers.sh" "$SOURCE_FILE"

  [ "$status" -ne 0 ]
  [[ "$output" == *"ripgrep"* ]]
}
