#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_REPOSITORY="$BATS_TEST_TMPDIR/repository"
  mkdir -p "$TEST_REPOSITORY/.ratchet" "$TEST_REPOSITORY/plugins/ratchet/scripts"
  cp "$PROJECT_ROOT/plugins/ratchet/scripts/ratchet.py" "$TEST_REPOSITORY/plugins/ratchet/scripts/ratchet.py"
  cp "$PROJECT_ROOT/plugins/ratchet/scripts/ratchet.sh" "$TEST_REPOSITORY/plugins/ratchet/scripts/ratchet.sh"
  chmod +x "$TEST_REPOSITORY/plugins/ratchet/scripts/ratchet.py" "$TEST_REPOSITORY/plugins/ratchet/scripts/ratchet.sh"

  write_configuration
  write_baseline 3
  write_report 3
  write_fake_adapter
}

write_configuration() {
  cat >"$TEST_REPOSITORY/.ratchet/config.json" <<'EOF'
{
  "schemaVersion": 1,
  "timeoutSeconds": 5,
  "adapters": {
    "fake": {
      "command": ["fake-adapter.sh"]
    }
  }
}
EOF
}

write_baseline() {
  local count="$1"
  cat >"$TEST_REPOSITORY/.ratchet/fake.json" <<EOF
{
  "schemaVersion": 1,
  "tool": "fake",
  "adapterVersion": 1,
  "coverage": {
    "lastAcceptedFileCount": 1,
    "allowEmpty": false
  },
  "rules": {
    "RULE_A": $count
  }
}
EOF
}

write_report() {
  local count="$1"
  local counts
  if [ "$count" -eq 0 ]; then
    counts='{}'
  else
    counts="{\"RULE_A\":$count}"
  fi
  cat >"$TEST_REPOSITORY/.ratchet/fake-report.json" <<EOF
{"schemaVersion":1,"tool":"fake","adapterVersion":1,"run":{"toolExitCode":1,"exitKind":"findings","reportFormat":"fake-json-v1","filesDiscovered":1,"filesInvoked":1,"coverageProof":"explicit-argv"},"counts":$counts}
EOF
}

write_fake_adapter() {
  cat >"$TEST_REPOSITORY/fake-adapter.sh" <<'EOF'
#!/bin/bash

set -Eeuo pipefail

operation="$1"
rule="${2:-}"

case "$operation" in
  scan)
    if [ -f .ratchet/crash ]; then
      echo "simulated linter crash" >&2
      exit 70
    fi
    cat .ratchet/fake-report.json
    ;;
  promote)
    printf '%s\n' "$rule" >enforcement.conf
    ;;
  promotion-status)
    enforced=false
    if [ -f enforcement.conf ] && [ "$(cat enforcement.conf)" = "$rule" ]; then
      enforced=true
    fi
    printf '{"schemaVersion":1,"tool":"fake","rule":"%s","enforced":%s,"source":"enforcement.conf"}\n' "$rule" "$enforced"
    ;;
  *)
    exit 64
    ;;
esac
EOF
  chmod +x "$TEST_REPOSITORY/fake-adapter.sh"
}

run_ratchet() {
  run bash -c 'command cd "$1" && shift && plugins/ratchet/scripts/ratchet.sh "$@"' _ "$TEST_REPOSITORY" "$@"
}

@test "crashing linter fails loudly and leaves the baseline byte-for-byte unchanged" {
  before="$(shasum -a 256 "$TEST_REPOSITORY/.ratchet/fake.json")"
  touch "$TEST_REPOSITORY/.ratchet/crash"

  run_ratchet accept fake

  after="$(shasum -a 256 "$TEST_REPOSITORY/.ratchet/fake.json")"
  [ "$status" -eq 2 ]
  [ "$output" = "ratchet: fake adapter failed (70): simulated linter crash" ]
  [ "$after" = "$before" ]
}

@test "check distinguishes regression, acceptance, and promotion states" {
  write_report 4
  run_ratchet check fake
  [ "$status" -eq 1 ]
  [ "$output" = $'tool\trule\tbaseline\tcurrent\tstate\nfake\tRULE_A\t3\t4\tregression' ]

  write_report 2
  run_ratchet check fake
  [ "$status" -eq 3 ]
  [ "$output" = $'tool\trule\tbaseline\tcurrent\tstate\nfake\tRULE_A\t3\t2\taccept\nRun: just ratchet-accept fake' ]

  write_report 0
  run_ratchet check fake
  [ "$status" -eq 4 ]
  [ "$output" = $'tool\trule\tbaseline\tcurrent\tstate\nfake\tRULE_A\t3\t0\tpromote\nRun: just ratchet-promote fake RULE_A' ]
}

@test "accept lowers only a positive count after a successful fresh scan" {
  write_report 2

  run_ratchet accept fake

  [ "$status" -eq 0 ]
  [ "$output" = "Accepted guarded decreases in .ratchet/fake.json" ]
  run jq --compact-output --sort-keys . "$TEST_REPOSITORY/.ratchet/fake.json"
  [ "$status" -eq 0 ]
  [ "$output" = '{"adapterVersion":1,"coverage":{"allowEmpty":false,"lastAcceptedFileCount":1},"rules":{"RULE_A":2},"schemaVersion":1,"tool":"fake"}' ]
}

@test "promotion verifies durable enforcement before deleting zero debt" {
  write_report 0

  run_ratchet promote fake RULE_A

  [ "$status" -eq 0 ]
  [ "$output" = "Promoted fake/RULE_A in enforcement.conf and updated .ratchet/fake.json" ]
  run jq --compact-output --sort-keys . "$TEST_REPOSITORY/.ratchet/fake.json"
  [ "$status" -eq 0 ]
  [ "$output" = '{"adapterVersion":1,"coverage":{"allowEmpty":false,"lastAcceptedFileCount":1},"rules":{},"schemaVersion":1,"tool":"fake"}' ]
  run cat "$TEST_REPOSITORY/enforcement.conf"
  [ "$status" -eq 0 ]
  [ "$output" = "RULE_A" ]
}

@test "repository lint adapters emit validated normalized envelopes" {
  run bash -c 'command cd "$1" && plugins/ratchet/adapters/shellcheck.sh scan' _ "$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  run jq --compact-output '{schemaVersion,tool,adapterVersion,run:{exitKind:.run.exitKind,reportFormat:.run.reportFormat,coverageProof:.run.coverageProof,coverageEqual:(.run.filesDiscovered == .run.filesInvoked)},counts}' <<<"$output"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"shellcheck","adapterVersion":1,"run":{"exitKind":"clean","reportFormat":"shellcheck-json-v1","coverageProof":"explicit-argv","coverageEqual":true},"counts":{}}' ]

  run bash -c 'command cd "$1" && plugins/ratchet/adapters/markdownlint.sh scan' _ "$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  run jq --compact-output '{schemaVersion,tool,adapterVersion,run:{exitKind:.run.exitKind,reportFormat:.run.reportFormat,coverageProof:.run.coverageProof,coverageEqual:(.run.filesDiscovered == .run.filesInvoked)},counts}' <<<"$output"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"markdownlint","adapterVersion":1,"run":{"exitKind":"clean","reportFormat":"markdownlint-cli2-json-v1","coverageProof":"explicit-argv","coverageEqual":true},"counts":{}}' ]

  run bash -c 'command cd "$1" && plugins/ratchet/adapters/yamllint.sh scan' _ "$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  run jq --compact-output '{schemaVersion,tool,adapterVersion,run:{exitKind:.run.exitKind,reportFormat:.run.reportFormat,coverageProof:.run.coverageProof,coverageEqual:(.run.filesDiscovered == .run.filesInvoked)},counts}' <<<"$output"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"yamllint","adapterVersion":1,"run":{"exitKind":"clean","reportFormat":"yamllint-parsable-v1","coverageProof":"explicit-argv","coverageEqual":true},"counts":{}}' ]
}

@test "shellcheck discovers extensionless Bash scripts by shebang" {
  discovery_repository="$BATS_TEST_TMPDIR/shellcheck-discovery"
  mkdir -p "$discovery_repository"
  git -C "$discovery_repository" init --quiet
  printf '#!/usr/bin/env bash\n' >"$discovery_repository/extensionless-script"
  printf '#!/bin/bash\n' >"$discovery_repository/script.sh"
  printf '#!/usr/bin/env bats\n' >"$discovery_repository/script.bats"
  printf '#!/usr/bin/env python3\n' >"$discovery_repository/script.py"

  run bash -c 'command cd "$1" && python "$2" shellcheck files' _ "$discovery_repository" "$PROJECT_ROOT/plugins/ratchet/adapters/lint_adapter.py"

  [ "$status" -eq 0 ]
  [ "$output" = "extensionless-script script.sh" ]
}

@test "lint adapters promote rules in durable tool configurations" {
  promotion_repository="$BATS_TEST_TMPDIR/promotion-repository"
  mkdir -p "$promotion_repository"
  cp "$PROJECT_ROOT/.markdownlint.jsonc" "$promotion_repository/.markdownlint.jsonc"
  cp "$PROJECT_ROOT/.yamllint.yaml" "$promotion_repository/.yamllint.yaml"
  printf 'disable=SC2086,SC2155\n' >"$promotion_repository/.shellcheckrc"
  printf '{"rules":{"eslint/no-debugger":"warn"}}\n' >"$promotion_repository/.oxlintrc.json"

  run bash -c 'command cd "$1" && python "$2" shellcheck promote SC2086 && python "$2" shellcheck promotion-status SC2086' _ "$promotion_repository" "$PROJECT_ROOT/plugins/ratchet/adapters/lint_adapter.py"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"shellcheck","rule":"SC2086","enforced":true,"source":".shellcheckrc"}' ]

  run bash -c 'command cd "$1" && python "$2" markdownlint promote MD010 && python "$2" markdownlint promotion-status MD010' _ "$promotion_repository" "$PROJECT_ROOT/plugins/ratchet/adapters/lint_adapter.py"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"markdownlint","rule":"MD010","enforced":true,"source":".markdownlint.jsonc"}' ]

  run bash -c 'command cd "$1" && python "$2" yamllint promote comments && python "$2" yamllint promotion-status comments' _ "$promotion_repository" "$PROJECT_ROOT/plugins/ratchet/adapters/lint_adapter.py"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"yamllint","rule":"comments","enforced":true,"source":".yamllint.yaml"}' ]

  run bash -c 'command cd "$1" && python "$2" oxlint promote "eslint(no-debugger)" && python "$2" oxlint promotion-status "eslint(no-debugger)"' _ "$promotion_repository" "$PROJECT_ROOT/plugins/ratchet/adapters/lint_adapter.py"
  [ "$status" -eq 0 ]
  [ "$output" = '{"schemaVersion":1,"tool":"oxlint","rule":"eslint(no-debugger)","enforced":true,"source":".oxlintrc.json"}' ]
}
