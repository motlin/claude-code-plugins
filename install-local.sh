#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_JSON="$SCRIPT_DIR/.claude-plugin/marketplace.json"
MARKETPLACE_NAME="$(jq -er .name "$MARKETPLACE_JSON")"

function plugin_names() {
    jq -r '.plugins[].name' "$MARKETPLACE_JSON"
}

function installed_plugins_json() {
    claude plugin list --json 2>/dev/null || echo '[]'
}

if claude plugin marketplace list --json 2>/dev/null |
    jq -e --arg n "$MARKETPLACE_NAME" '.[] | select(.name == $n)' >/dev/null; then
    echo "📥 Marketplace ${MARKETPLACE_NAME} already registered, skipping add."
else
    echo "📥 Adding ${MARKETPLACE_NAME} from local directory..."
    claude plugin marketplace add "$SCRIPT_DIR"
fi

installed_ids_json="$(installed_plugins_json)"

echo "🔧 Installing plugins..."
while read -r plugin; do
    plugin_id="${plugin}@${MARKETPLACE_NAME}"
    if jq -e --arg id "$plugin_id" 'any(.[]; .id == $id)' <<<"$installed_ids_json" >/dev/null; then
        echo "  - ${plugin_id} already installed, skipping."
    else
        echo "  - installing ${plugin_id}..."
        claude plugin install "$plugin_id"
    fi
done < <(plugin_names)

echo "🔌 Enabling plugins..."
plugin_states="$(installed_plugins_json)"
while read -r plugin; do
    plugin_id="${plugin}@${MARKETPLACE_NAME}"
    enabled="$(jq -r --arg id "$plugin_id" '.[] | select(.id == $id) | .enabled' <<<"$plugin_states")"
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
done < <(plugin_names)

echo "✅ Installation complete!"
