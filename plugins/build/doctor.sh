#!/bin/bash
# 🩺 Doctor script for build plugin
# Checks for required binaries and environment setup

set -e

PLUGIN_NAME="build"
ERRORS=0

echo "🩺 Running doctor checks for $PLUGIN_NAME plugin..."

# Check for just binary
if command -v just &> /dev/null; then
    echo "✅ just is installed ($(just --version))"
else
    echo "❌ just is not installed"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -eq 0 ]; then
    echo "🎉 All checks passed for $PLUGIN_NAME plugin"
    exit 0
else
    echo "⚠️  $ERRORS check(s) failed for $PLUGIN_NAME plugin"
    exit 1
fi
