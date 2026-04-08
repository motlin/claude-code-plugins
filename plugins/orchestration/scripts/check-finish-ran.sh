#!/usr/bin/env bash
set -Eeuo pipefail

# Consume stdin (hook protocol sends JSON, but we don't need it)
cat >/dev/null

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
    result=$(git test results HEAD 2>/dev/null || true)
    if [[ "$result" == unknown* ]]; then
        reasons+=("No git test results found for HEAD.")
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
echo "$count" >"$COUNTER_FILE"
if [[ "$count" -ge "$MAX_ATTEMPTS" ]]; then
    rm -f "$COUNTER_FILE"
    exit 0
fi

echo "❌ The finish pipeline has not run. Evidence:" >&2
for reason in "${reasons[@]}"; do
    echo "  - $reason" >&2
done
echo >&2
echo "Run the orchestration:finish agent now." >&2
echo "It handles building, committing, simplifying, and rebasing — the full completion pipeline." >&2
echo "Do not attempt individual steps yourself. The finish agent exists so nothing gets missed." >&2
echo >&2
echo "The build runs linters, formatters, and tests on every commit — including for docs and markdown." >&2
echo "There is no type of change that can skip the build. Even a one-line doc edit gets linted and formatted." >&2
exit 2
