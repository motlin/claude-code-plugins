#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_NAME="motlin-claude-code-plugins"

echo "📥 Adding ${MARKETPLACE_NAME} from local directory..."
claude plugin marketplace add "$SCRIPT_DIR"

echo "🔧 Installing plugins..."
jq -r '.plugins[].name' "$SCRIPT_DIR/.claude-plugin/marketplace.json" | while read -r plugin; do
    claude plugin install "${plugin}@${MARKETPLACE_NAME}"
done

echo "✅ Installation complete!"
