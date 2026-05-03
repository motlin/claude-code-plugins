#!/usr/bin/env bash
set -Eeuo pipefail

cat >/dev/null

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

if [[ ${#reasons[@]} -eq 0 ]]; then
    exit 0
fi

reason_list=$(printf " %s" "${reasons[@]}")
echo "${reason_list}" >&2
exit 0
