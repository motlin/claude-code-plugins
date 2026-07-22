#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_REPOSITORY="$BATS_TEST_TMPDIR/repository"
  mkdir -p "$TEST_REPOSITORY/.ratchet" "$TEST_REPOSITORY/bin" "$TEST_REPOSITORY/plugins/ratchet/adapters" "$TEST_REPOSITORY/plugins/ratchet/scripts" "$TEST_REPOSITORY/src" "$TEST_REPOSITORY/test"
  cp "$PROJECT_ROOT/plugins/ratchet/adapters/test_adapter.py" "$TEST_REPOSITORY/plugins/ratchet/adapters/test_adapter.py"
  cp "$PROJECT_ROOT/plugins/ratchet/adapters/vitest.sh" "$TEST_REPOSITORY/plugins/ratchet/adapters/vitest.sh"
  cp "$PROJECT_ROOT/plugins/ratchet/scripts/ratchet.py" "$TEST_REPOSITORY/plugins/ratchet/scripts/ratchet.py"
  cp "$PROJECT_ROOT/plugins/ratchet/scripts/ratchet.sh" "$TEST_REPOSITORY/plugins/ratchet/scripts/ratchet.sh"
  chmod +x "$TEST_REPOSITORY/plugins/ratchet/adapters/test_adapter.py" "$TEST_REPOSITORY/plugins/ratchet/adapters/vitest.sh" "$TEST_REPOSITORY/plugins/ratchet/scripts/ratchet.py" "$TEST_REPOSITORY/plugins/ratchet/scripts/ratchet.sh"
  printf 'export const covered = true;\n' >"$TEST_REPOSITORY/src/covered.ts"
  printf 'export const uncovered = false;\n' >"$TEST_REPOSITORY/src/uncovered.ts"
  printf 'test("alice", () => {});\n' >"$TEST_REPOSITORY/test/alice.test.ts"
  git -C "$TEST_REPOSITORY" init --quiet
  git -C "$TEST_REPOSITORY" add src test
  write_adapter_configuration
  write_ratchet_configuration
  write_baseline
  write_native_report 1
  write_fake_vitest
}

write_adapter_configuration() {
  cat >"$TEST_REPOSITORY/.ratchet/vitest-adapter.json" <<'EOF'
{
  "schemaVersion": 1,
  "command": ["bin/fake-vitest"],
  "sourceFileGlobs": ["src/*.ts", "src/**/*.ts"],
  "testFileGlobs": ["test/*.test.ts", "test/**/*.test.ts"],
  "enforcementFile": ".ratchet/vitest-enforcement.json"
}
EOF
}

write_ratchet_configuration() {
  cat >"$TEST_REPOSITORY/.ratchet/config.json" <<'EOF'
{
  "schemaVersion": 1,
  "timeoutSeconds": 5,
  "adapters": {
    "vitest": {
      "command": ["plugins/ratchet/adapters/vitest.sh"]
    }
  }
}
EOF
}

write_baseline() {
  cat >"$TEST_REPOSITORY/.ratchet/vitest.json" <<'EOF'
{
  "schemaVersion": 1,
  "tool": "vitest",
  "adapterVersion": 1,
  "coverage": {
    "lastAcceptedFileCount": 2,
    "allowEmpty": false
  },
  "rules": {
    "SKIPPED_TESTS": 1,
    "ZERO_TEST_FILES": 1
  }
}
EOF
}

write_native_report() {
  local skipped_count="$1"
  local pending_count="$skipped_count"
  local todo_count=0
  local assertions='[{"status":"passed"}]'
  if [ "$skipped_count" -eq 1 ]; then
    assertions='[{"status":"passed"},{"status":"skipped"}]'
  elif [ "$skipped_count" -eq 2 ]; then
    assertions='[{"status":"passed"},{"status":"skipped"},{"status":"todo"}]'
    pending_count=1
    todo_count=1
  fi
  cat >"$TEST_REPOSITORY/.ratchet/native-report.json" <<EOF
{
  "numFailedTests": 0,
  "numFailedTestSuites": 0,
  "numPassedTests": 1,
  "numPassedTestSuites": 1,
  "numPendingTests": $pending_count,
  "numPendingTestSuites": 0,
  "numTodoTests": $todo_count,
  "numTotalTests": $((skipped_count + 1)),
  "numTotalTestSuites": 1,
  "success": true,
  "testResults": [{"name":"$TEST_REPOSITORY/test/alice.test.ts","status":"passed","assertionResults":$assertions}],
  "coverageMap": {
    "$TEST_REPOSITORY/src/covered.ts": {"s":{"0":1}},
    "$TEST_REPOSITORY/src/uncovered.ts": {"s":{"0":0}}
  }
}
EOF
}

write_fake_vitest() {
  cat >"$TEST_REPOSITORY/bin/fake-vitest" <<'EOF'
#!/bin/bash

set -Eeuo pipefail

printf '%s\n' "$@" >.ratchet/vitest-arguments.txt
for argument in "$@"; do
  case "$argument" in
    --outputFile=*)
      cp .ratchet/native-report.json "${argument#--outputFile=}"
      ;;
  esac
done
EOF
  chmod +x "$TEST_REPOSITORY/bin/fake-vitest"
}

run_adapter() {
  run bash -c 'command cd "$1" && plugins/ratchet/adapters/vitest.sh scan' _ "$TEST_REPOSITORY"
}

run_ratchet() {
  run bash -c 'command cd "$1" && plugins/ratchet/scripts/ratchet.sh check vitest' _ "$TEST_REPOSITORY"
}

@test "Vitest adapter counts zero-test files and skipped tests from guarded machine output" {
  run_adapter

  [ "$status" -eq 0 ]
  run jq --compact-output '{schemaVersion,tool,adapterVersion,run,counts}' <<<"$output"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"vitest","adapterVersion":1,"run":{"toolExitCode":0,"exitKind":"findings","reportFormat":"vitest-json-v1+istanbul-coverage-v1","filesDiscovered":2,"filesInvoked":2,"coverageProof":"explicit-argv"},"counts":{"SKIPPED_TESTS":1,"ZERO_TEST_FILES":1}}' ]
  run cat "$TEST_REPOSITORY/.ratchet/vitest-arguments.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'--coverage.include=src/covered.ts\n--coverage.include=src/uncovered.ts'* ]]
  [[ "$output" == *$'--\ntest/alice.test.ts'* ]]
  run find "$TEST_REPOSITORY/.ratchet" -maxdepth 1 -name '.vitest-*' -print
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "test-quality regression fails loudly through the shared ratchet core" {
  write_native_report 2

  run_ratchet

  [ "$status" -eq 1 ]
  [ "$output" = $'tool\trule\tbaseline\tcurrent\tstate\nvitest\tSKIPPED_TESTS\t1\t2\tregression\nvitest\tZERO_TEST_FILES\t1\t1\tequal' ]
}

@test "Vitest adapter rejects incomplete coverage instead of accepting a false improvement" {
  python - "$TEST_REPOSITORY/.ratchet/native-report.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    report = json.load(handle)
del report["coverageMap"][next(iter(report["coverageMap"]))]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(report, handle)
PY

  run_adapter

  [ "$status" -eq 2 ]
  [ "$output" = "vitest adapter: Vitest coverage does not match the complete explicit source-file set" ]
}

@test "Vitest promotion records durable zero-debt enforcement" {
  run bash -c 'command cd "$1" && plugins/ratchet/adapters/vitest.sh promote SKIPPED_TESTS && plugins/ratchet/adapters/vitest.sh promotion-status SKIPPED_TESTS' _ "$TEST_REPOSITORY"

  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"vitest","rule":"SKIPPED_TESTS","enforced":true,"source":".ratchet/vitest-enforcement.json"}' ]
  run jq --compact-output . "$TEST_REPOSITORY/.ratchet/vitest-enforcement.json"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"enforcedRules":["SKIPPED_TESTS"]}' ]
}
