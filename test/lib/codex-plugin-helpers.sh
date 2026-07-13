#!/bin/bash

set -Eeuo pipefail

codex_plugin_validator() {
    printf '%s\n' "${CODEX_HOME:-$HOME/.codex}/skills/.system/plugin-creator/scripts/validate_plugin.py"
}

codex_supported_hook_events() {
    printf '%s\n' \
        PermissionRequest \
        PostCompact \
        PostToolUse \
        PreCompact \
        PreToolUse \
        SessionStart \
        Stop \
        SubagentStart \
        SubagentStop \
        UserPromptSubmit
}

extract_literal_plugin_script_references() {
    local skill_file="$1"

    rg --no-filename --only-matching --pcre2 \
        '(?:<plugin-root>|\$\{?CLAUDE_PLUGIN_ROOT\}?)/scripts/[A-Za-z0-9_./-]+' \
        "$skill_file" | sort --unique
}

validate_codex_hooks() {
    local hooks_file="$1"
    local supported_events
    supported_events="$(codex_supported_hook_events)"

    if ! jq --exit-status \
        'type == "object" and keys == ["hooks"] and (.hooks | type == "object" and length > 0)' \
        "$hooks_file" >/dev/null; then
        echo "Codex hooks must have the strict {\"hooks\": {...}} root: $hooks_file"
        return 1
    fi

    local event
    while IFS= read -r event; do
        if ! grep --fixed-strings --line-regexp --quiet "$event" <<<"$supported_events"; then
            echo "Unsupported Codex hook event '$event' in $hooks_file"
            return 1
        fi
    done < <(jq --raw-output '.hooks | keys[]' "$hooks_file")
}
