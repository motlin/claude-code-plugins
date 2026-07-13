#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "claude plugin validate marketplace.json passes" {
  run claude plugin validate "$PROJECT_ROOT/.claude-plugin/marketplace.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Validation passed"* ]]
}

@test "claude plugin validate every plugin.json passes" {
  failed=()
  for manifest in "$PROJECT_ROOT"/plugins/*/.claude-plugin/plugin.json; do
    if ! claude plugin validate "$manifest" >/dev/null 2>&1; then
      failed+=("$manifest")
    fi
  done
  if [ "${#failed[@]}" -ne 0 ]; then
    printf 'failed manifests:\n'
    printf '  %s\n' "${failed[@]}"
    return 1
  fi
}

@test "codex plugin versions share their claude plugin base versions" {
  for codex_manifest in "$PROJECT_ROOT"/plugins/*/.codex-plugin/plugin.json; do
    plugin_root="${codex_manifest%/.codex-plugin/plugin.json}"
    claude_manifest="$plugin_root/.claude-plugin/plugin.json"
    codex_version="$(jq --raw-output '.version' "$codex_manifest")"
    claude_version="$(jq --raw-output '.version' "$claude_manifest")"
    if [ "$codex_version" = "$claude_version" ]; then
      continue
    fi
    cachebuster="${codex_version#"$claude_version+codex."}"
    [ "$codex_version" = "$claude_version+codex.$cachebuster" ]
    [ -n "$cachebuster" ]
  done
}
