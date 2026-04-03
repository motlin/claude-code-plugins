#!/usr/bin/env bash
set -Eeuo pipefail

# Consume stdin (hook protocol sends JSON, but we don't need it)
cat > /dev/null

# Bypass: Claude creates this file to break a hook cycle or skip the pipeline
if [[ -f .llm/skip-pipeline ]]; then
    rm -f .llm/skip-pipeline
    exit 0
fi

messages=()

if ! git diff --ignore-submodules --quiet 2>/dev/null; then
    messages+=("Working tree has unstaged changes.")
fi

if ! git diff --ignore-submodules --staged --quiet 2>/dev/null; then
    messages+=("Staged changes have not been committed.")
fi

if git status --porcelain --ignore-submodules 2>/dev/null | grep -q '^??'; then
    messages+=("Untracked files exist.")
fi

if [[ ${#messages[@]} -gt 0 ]]; then
    echo "Local modifications detected:" >&2
    for msg in "${messages[@]}"; do
        echo "  - $msg" >&2
    done
    echo "Run /orchestration:finish to execute the full completion pipeline before stopping." >&2
    echo "To bypass, create .llm/skip-pipeline (e.g. to break a hook cycle)." >&2
    exit 2
fi

exit 0
