#!/bin/bash
# 🩺 Doctor script for github plugin
# Checks for required binaries and environment setup

set -e

PLUGIN_NAME="github"
ERRORS=0

echo "🩺 Running doctor checks for $PLUGIN_NAME plugin..."

# Check for gh binary
if command -v gh &> /dev/null; then
    echo "✅ gh is installed ($(gh --version | head -1))"
    # Check if authenticated
    if gh auth status &> /dev/null; then
        echo "✅ gh is authenticated"
    else
        echo "⚠️  gh is not authenticated"
        echo "   Authenticate with: gh auth login"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "❌ gh (GitHub CLI) is not installed"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -eq 0 ]; then
    echo "🎉 All checks passed for $PLUGIN_NAME plugin"
    exit 0
else
    echo "⚠️  $ERRORS check(s) failed for $PLUGIN_NAME plugin"
    exit 1
fi
