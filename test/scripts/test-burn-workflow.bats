#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "burn workflow script passes its node tests" {
  run node --test "$PROJECT_ROOT/plugins/burn/tests/workflow.test.mjs"

  echo "$output"
  [ "$status" -eq 0 ]
}
