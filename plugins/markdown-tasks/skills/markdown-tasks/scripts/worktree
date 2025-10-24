#!/usr/bin/env bash

set -Eeuo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: worktree <task-name>" >&2
    exit 1
fi

TASK_NAME="$1"

# Get the original repository name and paths
ORIGINAL_REPO_PATH="$(git rev-parse --show-toplevel)"
ORIGINAL_REPO_NAME=$(basename "$ORIGINAL_REPO_PATH")

# Create worktree and branch names
WORKTREE_NAME="${ORIGINAL_REPO_NAME}-${TASK_NAME}"
BRANCH_NAME="${TASK_NAME}"
WORKTREE_PATH="$(dirname "$ORIGINAL_REPO_PATH")/${WORKTREE_NAME}"

# Create the git worktree
echo "git worktree add --quiet \"$WORKTREE_PATH\" -b \"$BRANCH_NAME\" \"${UPSTREAM_REMOTE:-origin}/${UPSTREAM_BRANCH:-main}\""
git worktree add --quiet "$WORKTREE_PATH" -b "$BRANCH_NAME" "${UPSTREAM_REMOTE:-origin}/${UPSTREAM_BRANCH:-main}"

# Copy .envrc if it exists
if [ -f ".envrc" ]; then
    echo "cp \".envrc\" \"$WORKTREE_PATH/\""
    cp ".envrc" "$WORKTREE_PATH/"
    echo "direnv allow \"$WORKTREE_PATH\""
    direnv allow "$WORKTREE_PATH"
fi

# Copy .claude directory if it exists
if [ -d ".claude" ]; then
    echo "cp -r \".claude\" \"$WORKTREE_PATH/\""
    cp -r ".claude" "$WORKTREE_PATH/"
fi

# Copy .mise/config.local.toml if it exists
if [ -f ".mise/config.local.toml" ]; then
    echo "mkdir -p \"$WORKTREE_PATH/.mise\""
    mkdir -p "$WORKTREE_PATH/.mise"
    echo "cp \".mise/config.local.toml\" \"$WORKTREE_PATH/.mise/\""
    cp ".mise/config.local.toml" "$WORKTREE_PATH/.mise/"
fi

# Copy .llm directory if it exists
if [ -d ".llm" ]; then
    echo "cp -r \".llm\" \"$WORKTREE_PATH/\""
    cp -r ".llm" "$WORKTREE_PATH/"
fi

# Copy CLAUDE.local.md if it exists
if [ -f "CLAUDE.local.md" ]; then
    echo "cp \"CLAUDE.local.md\" \"$WORKTREE_PATH/\""
    cp "CLAUDE.local.md" "$WORKTREE_PATH/"
fi

# Copy .serena directory if it exists
if [ -d ".serena" ]; then
    echo "cp -r \".serena\" \"$WORKTREE_PATH/\""
    cp -r ".serena" "$WORKTREE_PATH/"
fi

# Trust with mise
echo "mise trust \"$WORKTREE_PATH\""
mise trust "$WORKTREE_PATH"

echo "✅ Worktree created successfully!"
echo "📁 Path: ${WORKTREE_PATH}"
echo "🚀 Run: cd ${WORKTREE_PATH}"
