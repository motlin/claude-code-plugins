#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_BIN="$BATS_TEST_TMPDIR/bin"
    COMMAND_LOG="$BATS_TEST_TMPDIR/commands.log"
    mkdir -p "$TEST_BIN"
    : >"$COMMAND_LOG"
    export COMMAND_LOG PROJECT_ROOT
    export PATH="$TEST_BIN:$PATH"
}

function write_claude_stub() {
    cat >"$TEST_BIN/claude" <<'EOF'
#!/bin/bash
echo "claude $*" >>"$COMMAND_LOG"
case "$*" in
    "plugin marketplace list --json")
        echo '[{"name":"motlin-claude-code-plugins"}]'
        ;;
    "plugin list --json")
        jq '[.plugins[] | {id: (.name + "@motlin-claude-code-plugins"), enabled: true}]' \
            "$PROJECT_ROOT/.claude-plugin/marketplace.json"
        ;;
esac
EOF
    chmod +x "$TEST_BIN/claude"
}

function write_codex_stub() {
    cat >"$TEST_BIN/codex" <<'EOF'
#!/bin/bash
echo "codex $*" >>"$COMMAND_LOG"
case "$*" in
    "plugin marketplace list --json")
        jq -n --arg root "$PROJECT_ROOT" \
            '{marketplaces: [{name: "motlin-claude-code-plugins", root: $root}]}'
        ;;
    "plugin list --json")
        jq '{installed: [.plugins[] | select(.name == "code") |
            {pluginId: (.name + "@motlin-claude-code-plugins")} ]}' \
            "$PROJECT_ROOT/.agents/plugins/marketplace.json"
        ;;
esac
EOF
    chmod +x "$TEST_BIN/codex"
}

@test "no argument preserves the Claude-only installation contract" {
    write_claude_stub

    run "$PROJECT_ROOT/install-local.sh"

    [ "$status" -eq 0 ]
    grep -Fqx "claude plugin marketplace list --json" "$COMMAND_LOG"
    run grep -q '^codex ' "$COMMAND_LOG"
    [ "$status" -eq 1 ]
}

@test "Codex mode installs only available plugins and refreshes installed cache entries" {
    write_codex_stub

    run "$PROJECT_ROOT/install-local.sh" codex

    [ "$status" -eq 0 ]
    expected_plugins="$(jq -r \
        '.plugins[] | select(.policy.installation == "AVAILABLE") | .name' \
        "$PROJECT_ROOT/.agents/plugins/marketplace.json" | sort)"
    installed_plugins="$(sed -n \
        's/^codex plugin add \([^@]*\)@motlin-claude-code-plugins$/\1/p' \
        "$COMMAND_LOG" | sort)"
    [ "$installed_plugins" = "$expected_plugins" ]
    grep -Fqx "codex plugin remove code@motlin-claude-code-plugins" "$COMMAND_LOG"

    while read -r plugin; do
        ! grep -Fq "codex plugin add ${plugin}@motlin-claude-code-plugins" "$COMMAND_LOG"
    done < <(jq -r '.plugins[] | select(.policy.installation == "NOT_AVAILABLE") | .name' \
        "$PROJECT_ROOT/.agents/plugins/marketplace.json")
}

@test "unknown installation target fails with usage" {
    run "$PROJECT_ROOT/install-local.sh" unsupported

    [ "$status" -eq 2 ]
    [[ "$output" == Usage:* ]]
}
