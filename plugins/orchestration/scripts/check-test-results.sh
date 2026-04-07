#!/usr/bin/env bash
set -Eeuo pipefail

# Consume stdin (hook protocol sends JSON, but we don't need it)
cat >/dev/null

# Bypass: Claude creates this file to break a hook cycle
if [[ -f .llm/skip-test-check ]]; then
    rm -f .llm/skip-test-check .llm/stop-hook-attempts
    exit 0
fi

# Allow stop after 3 failed attempts to avoid infinite hook loops
COUNTER_FILE=".llm/stop-hook-attempts"
MAX_ATTEMPTS=3
count=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" >"$COUNTER_FILE"
if [[ "$count" -ge "$MAX_ATTEMPTS" ]]; then
    rm -f "$COUNTER_FILE"
    exit 0
fi

# Check if git-test is available
if ! command -v git-test &>/dev/null; then
    exit 0
fi

result=$(git test results HEAD 2>/dev/null || true)

if [[ "$result" == unknown* ]]; then
    echo "❌ No git test results found for HEAD." >&2
    echo >&2
    echo "This means you have not run /orchestration:finish yet. Run /orchestration:finish now." >&2
    echo "/orchestration:finish handles building, committing, simplifying, and rebasing — the full completion pipeline." >&2
    echo "Do not attempt individual steps yourself. /orchestration:finish exists so nothing gets missed." >&2
    echo >&2
    echo "The build runs linters, formatters, and tests on every commit — including for docs and markdown." >&2
    echo "There is no type of change that can skip the build. Even a one-line doc edit gets linted and formatted." >&2
    echo "If you skip /orchestration:finish, the user must run it manually, wasting their time." >&2
    echo >&2
    echo "The .llm/skip-test-check file is ONLY for breaking out of a retry loop." >&2
    echo "Do not create .llm/skip-test-check on the first attempt. Run /orchestration:finish first." >&2
    exit 2
fi

rm -f "$COUNTER_FILE"
exit 0
