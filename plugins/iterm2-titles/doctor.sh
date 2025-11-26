#!/bin/bash
# 🩺 Doctor script for iterm2-titles plugin
# Checks for required binaries and environment setup

set -e

PLUGIN_NAME="iterm2-titles"
ERRORS=0

echo "🩺 Running doctor checks for $PLUGIN_NAME plugin..."

# Check for python3 binary
if command -v python3 &> /dev/null; then
    echo "✅ python3 is installed ($(python3 --version))"
else
    echo "❌ python3 is not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check if running in iTerm2
if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
    echo "✅ Running in iTerm2"
else
    echo "⚠️  Not running in iTerm2 (TERM_PROGRAM=$TERM_PROGRAM)"
    echo "   This plugin only works in iTerm2"
fi

if [ $ERRORS -eq 0 ]; then
    echo "🎉 All checks passed for $PLUGIN_NAME plugin"
    exit 0
else
    echo "⚠️  $ERRORS check(s) failed for $PLUGIN_NAME plugin"
    exit 1
fi
