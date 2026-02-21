#!/usr/bin/env bash

set -Eeuo pipefail

json=$(cat)

echo "$json" > /tmp/worktree-create-hook-input.json

source_dir=$(echo "$json" | jq --raw-output '.cwd')
worktree_dir=$(echo "$json" | jq --raw-output '
  .worktree_path
  // .worktreePath
  // .target_path
  // .targetPath
  // .path
')

if [ -z "$source_dir" ] || [ "$source_dir" = "null" ]; then
  echo "Error: could not determine source directory from hook input" >&2
  exit 1
fi

if [ -z "$worktree_dir" ] || [ "$worktree_dir" = "null" ]; then
  echo "Error: could not determine worktree directory from hook input" >&2
  exit 1
fi

echo "Copying gitignored files from $source_dir to $worktree_dir"

git -C "$source_dir" ls-files --others --ignored --exclude-standard -z \
  | rsync --archive --files-from=- --from0 "$source_dir/" "$worktree_dir/"

if [ -f "$worktree_dir/.envrc" ] && command -v direnv &> /dev/null; then
  echo "Running direnv allow in $worktree_dir"
  direnv allow "$worktree_dir"
fi

mise_configs=(".mise.toml" ".mise/config.toml" ".mise.local.toml" ".mise/config.local.toml" "mise.toml")
for config in "${mise_configs[@]}"; do
  if [ -f "$worktree_dir/$config" ] && command -v mise &> /dev/null; then
    echo "Running mise trust in $worktree_dir"
    mise trust "$worktree_dir"
    break
  fi
done

echo "Worktree setup complete"
