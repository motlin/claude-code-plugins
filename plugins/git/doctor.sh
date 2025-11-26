#!/bin/bash
# 🩺 Doctor script for git plugin
# Checks for required binaries and environment setup

set -e

PLUGIN_NAME="git"
ERRORS=0

echo "🩺 Running doctor checks for $PLUGIN_NAME plugin..."

# Check for git binary
if command -v git &> /dev/null; then
    echo "✅ git is installed ($(git --version))"
else
    echo "❌ git is not installed"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -eq 0 ]; then
    echo "🎉 All checks passed for $PLUGIN_NAME plugin"
    exit 0
else
    echo "⚠️  $ERRORS check(s) failed for $PLUGIN_NAME plugin"
    exit 1
fi
