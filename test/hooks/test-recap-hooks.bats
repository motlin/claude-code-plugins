#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PLUGIN_DIR="$PROJECT_ROOT/plugins/recap"
  MOD_HOOKS="$PLUGIN_DIR/mod/hooks.json"
}

# The footer is drawn by a function-hooks module that only Claude Code loads.
# Its config lives outside hooks/ so Codex's default hook discovery never reads
# a "modules" root it cannot run.
@test "recap Claude manifest points its hooks at the mod config" {
  hooks=$(jq --raw-output '.hooks' "$PLUGIN_DIR/.claude-plugin/plugin.json")
  [ "$hooks" = "./mod/hooks.json" ]
}

@test "recap mod config names one existing module" {
  modules=$(jq --raw-output '.modules | length' "$MOD_HOOKS")
  [ "$modules" -eq 1 ]
  module=$(jq --raw-output '.modules[0]' "$MOD_HOOKS")
  [ -f "$PLUGIN_DIR/mod/$module" ]
}

@test "recap has no default hook config for Codex to discover" {
  [ ! -e "$PLUGIN_DIR/hooks/hooks.json" ]
}

@test "recap no longer ships the blocking Stop guard" {
  [ ! -e "$PLUGIN_DIR/scripts/recap-guard.sh" ]
}

@test "recap mod tests pass" {
  run claude plugin test "$PLUGIN_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *" 0 fail"* ]]
}
