#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "upstream-sync workflow script passes its node tests" {
  run node --test "$PROJECT_ROOT/plugins/upstream-sync/tests/workflow.test.mjs"

  echo "$output"
  [ "$status" -eq 0 ]
}
