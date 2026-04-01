#!/usr/bin/env bash
set -Eeuo pipefail

# Consume stdin (hook protocol sends JSON, but we don't need it)
cat > /dev/null

# Bypass: Claude creates this file to break a hook cycle or skip the pipeline
if [[ -f .llm/skip-pipeline ]]; then
    rm -f .llm/skip-pipeline
    exit 0
fi

# Check if git-test is available
if ! command -v git-test &>/dev/null; then
    exit 0
fi

result=$(git test results HEAD 2>/dev/null || true)

if [[ "$result" == unknown* ]]; then
    echo "Tests have not been run on HEAD." >&2
    echo "Run /finish to execute the full completion pipeline before stopping." >&2
    echo "To bypass, create .llm/skip-pipeline (e.g. to break a hook cycle)." >&2
    exit 2
fi

exit 0
