#!/bin/bash
# Doctor script for worktree-setup plugin
# Checks for required and optional binaries

set -e

PLUGIN_NAME="worktree-setup"
ERRORS=0
WARNINGS=0

echo "Running doctor checks for $PLUGIN_NAME plugin..."

# Required tools
if command -v git &> /dev/null; then
    echo "git is installed ($(git --version))"
else
    echo "git is not installed"
    ERRORS=$((ERRORS + 1))
fi

if command -v jq &> /dev/null; then
    echo "jq is installed ($(jq --version))"
else
    echo "jq is not installed"
    ERRORS=$((ERRORS + 1))
fi

if command -v rsync &> /dev/null; then
    echo "rsync is installed ($(rsync --version | head -1))"
else
    echo "rsync is not installed"
    ERRORS=$((ERRORS + 1))
fi

# Optional tools
if command -v direnv &> /dev/null; then
    echo "direnv is installed ($(direnv version))"
else
    echo "direnv is not installed (optional - needed for .envrc support)"
    WARNINGS=$((WARNINGS + 1))
fi

if command -v mise &> /dev/null; then
    echo "mise is installed ($(mise --version))"
else
    echo "mise is not installed (optional - needed for mise config support)"
    WARNINGS=$((WARNINGS + 1))
fi

if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -gt 0 ]; then
        echo "All required checks passed for $PLUGIN_NAME plugin ($WARNINGS optional warning(s))"
    else
        echo "All checks passed for $PLUGIN_NAME plugin"
    fi
    exit 0
else
    echo "$ERRORS check(s) failed for $PLUGIN_NAME plugin"
    exit 1
fi
