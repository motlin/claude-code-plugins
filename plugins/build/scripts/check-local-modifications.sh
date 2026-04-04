#!/usr/bin/env bash
set -Eeuo pipefail

# Consume stdin (hook protocol sends JSON, but we don't need it)
cat > /dev/null

# Bypass: Claude creates this file to break a hook cycle
if [[ -f .llm/skip-modifications-check ]]; then
    rm -f .llm/skip-modifications-check
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
    echo "ALWAYS commit your changes before stopping. Do not leave the working tree dirty." >&2
    echo "If you skip this, the user must clean up manually, wasting their time." >&2
    echo "Run /orchestration:finish to execute the full completion pipeline before stopping." >&2
    echo >&2
    echo "The .llm/skip-modifications-check file is ONLY for breaking out of a retry loop." >&2
    echo "Do not create .llm/skip-modifications-check on the first attempt. Commit your changes first." >&2
    exit 2
fi

exit 0
