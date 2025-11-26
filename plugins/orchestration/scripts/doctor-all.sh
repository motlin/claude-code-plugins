#!/bin/bash
# 🩺 Master doctor script that runs all plugin doctor scripts
# Runs doctor.sh from each plugin directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🏥 Running doctor checks for all plugins..."
echo "=============================================="
echo ""

TOTAL_ERRORS=0
PLUGINS_CHECKED=0
PLUGINS_FAILED=0

for plugin_dir in "$PLUGINS_DIR"/*/; do
    plugin_name=$(basename "$plugin_dir")
    doctor_script="$plugin_dir/doctor.sh"

    if [ -f "$doctor_script" ]; then
        echo "📋 Checking $plugin_name..."
        echo "----------------------------------------------"

        if "$doctor_script"; then
            echo ""
        else
            PLUGINS_FAILED=$((PLUGINS_FAILED + 1))
            echo ""
        fi

        PLUGINS_CHECKED=$((PLUGINS_CHECKED + 1))
    fi
done

echo "=============================================="
echo "🏁 Doctor Summary"
echo "=============================================="
echo "   Plugins checked: $PLUGINS_CHECKED"
echo "   Plugins failed:  $PLUGINS_FAILED"

if [ $PLUGINS_FAILED -eq 0 ]; then
    echo ""
    echo "🎉 All plugins are healthy!"
    exit 0
else
    echo ""
    echo "⚠️  Some plugins have issues. Please review the errors above."
    exit 1
fi
