#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_MARKETPLACE_JSON="$SCRIPT_DIR/.claude-plugin/marketplace.json"
CODEX_MARKETPLACE_JSON="$SCRIPT_DIR/.agents/plugins/marketplace.json"
MARKETPLACE_NAME="$(jq -er .name "$CLAUDE_MARKETPLACE_JSON")"

function claude_plugin_names() {
    jq -r '.plugins[].name' "$CLAUDE_MARKETPLACE_JSON"
}

function codex_plugin_names() {
    jq -r '.plugins[] | select(.policy.installation == "AVAILABLE") | .name' \
        "$CODEX_MARKETPLACE_JSON"
}

function claude_installed_plugins_json() {
    claude plugin list --json 2>/dev/null || echo '[]'
}

function codex_installed_plugins_json() {
    codex plugin list --json 2>/dev/null || echo '{"installed": []}'
}

function install_claude_plugins() {
    if claude plugin marketplace list --json 2>/dev/null |
        jq -e --arg name "$MARKETPLACE_NAME" '.[] | select(.name == $name)' >/dev/null; then
        echo "📥 Claude marketplace ${MARKETPLACE_NAME} already registered, skipping add."
    else
        echo "📥 Adding ${MARKETPLACE_NAME} to Claude Code from the local directory..."
        claude plugin marketplace add "$SCRIPT_DIR"
    fi

    installed_plugins_json="$(claude_installed_plugins_json)"

    echo "🔧 Installing Claude Code plugins..."
    while read -r plugin; do
        plugin_id="${plugin}@${MARKETPLACE_NAME}"
        if jq -e --arg id "$plugin_id" 'any(.[]; .id == $id)' \
            <<<"$installed_plugins_json" >/dev/null; then
            echo "  - ${plugin_id} already installed, skipping."
        else
            echo "  - installing ${plugin_id}..."
            claude plugin install "$plugin_id"
        fi
    done < <(claude_plugin_names)

    echo "🔌 Enabling Claude Code plugins..."
    plugin_states="$(claude_installed_plugins_json)"
    while read -r plugin; do
        plugin_id="${plugin}@${MARKETPLACE_NAME}"
        enabled="$(jq -r --arg id "$plugin_id" '.[] | select(.id == $id) | .enabled' \
            <<<"$plugin_states")"
        case "$enabled" in
            true)
                echo "  - ${plugin_id} already enabled, skipping."
                ;;
            false)
                echo "  - enabling ${plugin_id}..."
                claude plugin enable "$plugin_id"
                ;;
            *)
                echo "  ❌ ${plugin_id} not found after install — something went wrong." >&2
                exit 1
                ;;
        esac
    done < <(claude_plugin_names)
}

function install_codex_plugins() {
    marketplace_root="$(codex plugin marketplace list --json 2>/dev/null |
        jq -r --arg name "$MARKETPLACE_NAME" \
            '.marketplaces[]? | select(.name == $name) | .root' | head -n 1)"

    if [[ -n "$marketplace_root" && "$marketplace_root" != "$SCRIPT_DIR" ]]; then
        echo "📥 Replacing ${MARKETPLACE_NAME} with the local Codex marketplace..."
        codex plugin marketplace remove "$MARKETPLACE_NAME"
        marketplace_root=""
    fi

    if [[ "$marketplace_root" == "$SCRIPT_DIR" ]]; then
        echo "📥 Codex marketplace ${MARKETPLACE_NAME} already points to this checkout."
    else
        echo "📥 Adding ${MARKETPLACE_NAME} to Codex from the local directory..."
        codex plugin marketplace add "$SCRIPT_DIR"
    fi

    installed_plugins_json="$(codex_installed_plugins_json)"

    echo "🔧 Installing Codex-compatible plugins..."
    while read -r plugin; do
        plugin_id="${plugin}@${MARKETPLACE_NAME}"
        if jq -e --arg id "$plugin_id" 'any(.installed[]?; .pluginId == $id)' \
            <<<"$installed_plugins_json" >/dev/null; then
            echo "  - reinstalling ${plugin_id} to refresh the local cache..."
            codex plugin remove "$plugin_id"
        else
            echo "  - installing ${plugin_id}..."
        fi
        codex plugin add "$plugin_id"
    done < <(codex_plugin_names)
}

function print_usage() {
    echo "Usage: $0 [claude|codex|all]" >&2
}

target="${1:-claude}"
if (($# > 1)); then
    print_usage
    exit 2
fi

case "$target" in
    claude)
        install_claude_plugins
        ;;
    codex)
        install_codex_plugins
        ;;
    all)
        install_claude_plugins
        install_codex_plugins
        ;;
    *)
        print_usage
        exit 2
        ;;
esac

echo "✅ Installation complete!"
