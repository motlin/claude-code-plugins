#!/usr/bin/env bash
set -Eeuo pipefail

cat >/dev/null

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

if ! command -v git-test &>/dev/null; then
    exit 0
fi

if ! "${CLAUDE_PLUGIN_ROOT}/scripts/check-battery"; then
    exit 0
fi

result=$(git test results HEAD 2>/dev/null || true)
if [[ "$result" == unknown* ]]; then
    echo " No git test results found for HEAD." >&2
fi

exit 0
