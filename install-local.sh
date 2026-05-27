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

echo "✅ Installation complete!"
