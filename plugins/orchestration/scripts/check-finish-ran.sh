#!/usr/bin/env bash
set -Eeuo pipefail

# Consume stdin (hook protocol sends JSON, but we don't need it)
cat >/dev/null

# Bypass: Claude creates this file to break a hook cycle
if [[ -f .llm/skip-finish-check ]]; then
    rm -f .llm/skip-finish-check .llm/stop-hook-attempts
    exit 0
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

reasons=()

if ! git diff --ignore-submodules --quiet 2>/dev/null; then
    reasons+=("Working tree has unstaged changes.")
fi

if ! git diff --ignore-submodules --staged --quiet 2>/dev/null; then
    reasons+=("Staged changes have not been committed.")
fi

if git status --porcelain --ignore-submodules 2>/dev/null | grep -q '^??'; then
    reasons+=("Untracked files exist.")
fi

if command -v git-test &>/dev/null; then
    CHECK_BATTERY="$(cd "$(dirname "$0")/../../build/scripts" && pwd)/check-battery"
    if "$CHECK_BATTERY"; then
        result=$(git test results HEAD 2>/dev/null || true)
        if [[ "$result" == unknown* ]]; then
            reasons+=("No git test results found for HEAD.")
        fi
    fi
fi

if [[ ${#reasons[@]} -eq 0 ]]; then
    exit 0
fi

# Allow stop after 3 failed attempts to avoid infinite hook loops
COUNTER_FILE=".llm/stop-hook-attempts"
MAX_ATTEMPTS=3
count=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
count=$((count + 1))
mkdir -p "$(dirname "$COUNTER_FILE")"
echo "$count" >"$COUNTER_FILE"
if [[ "$count" -ge "$MAX_ATTEMPTS" ]]; then
    rm -f "$COUNTER_FILE"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
reason_list=$(printf " %s" "${reasons[@]}")
echo "❌${reason_list} Read $SCRIPT_DIR/finish-not-run.md" >&2
exit 2
