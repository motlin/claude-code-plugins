#!/usr/bin/env bash

set -euo pipefail

MARKETPLACE_NAME="motlin-claude-code-plugins"

PLUGINS=(
    "markdown-tasks"
    "iterm2-titles"
    "tmux-titles"
    "build"
    "code-quality"
    "git"
    "java-maven"
    "justfile"
)

for plugin in "${PLUGINS[@]}"; do
    echo "claude plugin uninstall $plugin@$MARKETPLACE_NAME"
    claude plugin uninstall "$plugin@$MARKETPLACE_NAME" || true
done

echo "claude plugin marketplace remove $MARKETPLACE_NAME"
claude plugin marketplace remove "$MARKETPLACE_NAME" || true

echo "claude plugin marketplace add motlin/claude-code-plugins"
claude plugin marketplace add "motlin/claude-code-plugins"

for plugin in "${PLUGINS[@]}"; do
    echo "claude plugin install $plugin@$MARKETPLACE_NAME"
    claude plugin install "$plugin@$MARKETPLACE_NAME"
done
