#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=test/lib/codex-plugin-helpers.sh
  source "$PROJECT_ROOT/test/lib/codex-plugin-helpers.sh"
}

@test "Codex marketplace exposes compatible guard plugins" {
  marketplace="$PROJECT_ROOT/.agents/plugins/marketplace.json"

  for plugin in bash-guards git-guards stop-phrase-guard; do
    installation=$(jq --raw-output --arg plugin "$plugin" \
      '.plugins[] | select(.name == $plugin) | .policy.installation' "$marketplace")
    [ "$installation" = "AVAILABLE" ]
  done
}

@test "Codex guard manifests use default hook discovery" {
  for plugin in bash-guards git-guards stop-phrase-guard; do
    plugin_root="$PROJECT_ROOT/plugins/$plugin"
    manifest="$plugin_root/.codex-plugin/plugin.json"

    [ "$(jq --raw-output '.name' "$manifest")" = "$plugin" ]
    [ "$(jq --raw-output 'has("hooks")' "$manifest")" = "false" ]
    [ -f "$plugin_root/hooks/hooks.json" ]
    validate_codex_hooks "$plugin_root/hooks/hooks.json"
  done
}
