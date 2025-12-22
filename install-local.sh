#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Removing existing motlin-claude-code-plugins (if present)..."
claude plugin marketplace remove motlin-claude-code-plugins || true

echo "📥 Adding motlin-claude-code-plugins from local directory..."
claude plugin marketplace add "$SCRIPT_DIR"

echo "🔧 Installing plugins..."
claude plugin install build@motlin-claude-code-plugins
claude plugin install code@motlin-claude-code-plugins
claude plugin install git@motlin-claude-code-plugins
claude plugin install github@motlin-claude-code-plugins
claude plugin install iterm2-titles@motlin-claude-code-plugins
claude plugin install java@motlin-claude-code-plugins
claude plugin install justfile@motlin-claude-code-plugins
claude plugin install markdown-tasks@motlin-claude-code-plugins
claude plugin install offline-claude-code-guide@motlin-claude-code-plugins
claude plugin install orchestration@motlin-claude-code-plugins
claude plugin install pushover@motlin-claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins

echo "✅ Installation complete!"
