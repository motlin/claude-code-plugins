#!/bin/bash
# 🩺 Doctor script for markdown-tasks plugin
# Checks for required binaries and environment setup

set -e

PLUGIN_NAME="markdown-tasks"
ERRORS=0

echo "🩺 Running doctor checks for $PLUGIN_NAME plugin..."

# Check for python3 binary
if command -v python3 &> /dev/null; then
    echo "✅ python3 is installed ($(python3 --version))"
else
    echo "❌ python3 is not installed"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -eq 0 ]; then
    echo "🎉 All checks passed for $PLUGIN_NAME plugin"
    exit 0
else
    echo "⚠️  $ERRORS check(s) failed for $PLUGIN_NAME plugin"
    exit 1
fi
