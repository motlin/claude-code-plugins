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
