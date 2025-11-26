#!/bin/bash
# 🩺 Doctor script for java plugin
# Checks for required binaries and environment setup

set -e

PLUGIN_NAME="java"
ERRORS=0

echo "🩺 Running doctor checks for $PLUGIN_NAME plugin..."

# Check for java binary (optional but recommended)
if command -v java &> /dev/null; then
    echo "✅ java is installed ($(java -version 2>&1 | head -1))"
else
    echo "⚠️  java is not installed"
    echo "   This plugin works with Maven projects that require Java"
fi

# Check for mvn binary (optional but recommended)
if command -v mvn &> /dev/null; then
    echo "✅ mvn is installed ($(mvn --version | head -1))"
else
    echo "⚠️  mvn (Maven) is not installed"
fi

if [ $ERRORS -eq 0 ]; then
    echo "🎉 All checks passed for $PLUGIN_NAME plugin"
    exit 0
else
    echo "⚠️  $ERRORS check(s) failed for $PLUGIN_NAME plugin"
    exit 1
fi
