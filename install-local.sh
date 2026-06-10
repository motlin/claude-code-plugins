#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_JSON="$SCRIPT_DIR/.claude-plugin/marketplace.json"
MARKETPLACE_NAME="$(jq -r .name "$MARKETPLACE_JSON")"

if claude plugin marketplace list --json 2>/dev/null |
    jq -e --arg n "$MARKETPLACE_NAME" '.[] | select(.name == $n)' >/dev/null; then
    echo "📥 Marketplace ${MARKETPLACE_NAME} already registered, skipping add."
else
    echo "📥 Adding ${MARKETPLACE_NAME} from local directory..."
    claude plugin marketplace add "$SCRIPT_DIR"
fi

installed_ids="$(claude plugin list --json 2>/dev/null | jq -r '.[].id')"

echo "🔧 Installing plugins..."
jq -r '.plugins[].name' "$MARKETPLACE_JSON" | while read -r plugin; do
    plugin_id="${plugin}@${MARKETPLACE_NAME}"
    if grep -Fxq "$plugin_id" <<<"$installed_ids"; then
        echo "  - ${plugin_id} already installed, skipping."
    else
        echo "  - installing ${plugin_id}..."
        claude plugin install "$plugin_id"
    fi
done

echo "🔌 Enabling plugins..."
plugin_states="$(claude plugin list --json 2>/dev/null)"
jq -r '.plugins[].name' "$MARKETPLACE_JSON" | while read -r plugin; do
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
done

echo "✅ Installation complete!"
