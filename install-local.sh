#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_NAME="motlin-claude-code-plugins"

PLUGINS=(
    "markdown-tasks"
    "iterm2-titles"
    "tmux-titles"
    "git-worktree"
    "build-automation"
    "code-quality"
    "git-workflow"
    "java-maven"
    "justfile-utils"
)

for plugin in "${PLUGINS[@]}"; do
    echo "claude plugin uninstall $plugin@$MARKETPLACE_NAME"
    claude plugin uninstall "$plugin@$MARKETPLACE_NAME" || true
done

echo "claude plugin marketplace remove $MARKETPLACE_NAME"
claude plugin marketplace remove "$MARKETPLACE_NAME" || true

echo "claude plugin marketplace add $SCRIPT_DIR"
claude plugin marketplace add "$SCRIPT_DIR"

mkdir -p ~/.claude/plugins/marketplaces/motlin-claude-code-plugins
ln -sf "$SCRIPT_DIR/plugins" ~/.claude/plugins/marketplaces/motlin-claude-code-plugins/plugins
ln -sf "$SCRIPT_DIR/.claude-plugin" ~/.claude/plugins/marketplaces/motlin-claude-code-plugins/.claude-plugin

for plugin in "${PLUGINS[@]}"; do
    echo "claude plugin install $plugin@$MARKETPLACE_NAME"
    claude plugin install "$plugin@$MARKETPLACE_NAME"
done
