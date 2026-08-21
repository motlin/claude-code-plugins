#!/usr/bin/env bash

set -Eeuo pipefail

json=$(cat)

echo "$json" >/tmp/worktree-create-hook-input.json

source_dir=$(echo "$json" | jq --raw-output '.cwd')
worktree_dir=$(echo "$json" | jq --raw-output '
  .worktree_path
  // .worktreePath
  // .target_path
  // .targetPath
  // .path
  // empty
')

if [ -z "$source_dir" ] || [ "$source_dir" = "null" ]; then
    echo "Error: could not determine source directory from hook input" >&2
    exit 1
fi

# The current hook input carries only cwd + name, not a path: the harness
# fully delegates worktree creation to this hook when it's registered, rather
# than pre-creating the worktree and just asking us to decorate it. EnterWorktree's
# own docs say it "creates a new git worktree inside .claude/worktrees/", so
# that's the target when no explicit path field is present.
name=""
if [ -z "$worktree_dir" ] || [ "$worktree_dir" = "null" ]; then
    name=$(echo "$json" | jq --raw-output '.name // empty')
    if [ -z "$name" ]; then
        echo "Error: could not determine worktree directory from hook input" >&2
        exit 1
    fi
    worktree_dir="$source_dir/.claude/worktrees/$name"
fi

if [ ! -d "$worktree_dir" ]; then
    branch_name="${name:-$(basename "$worktree_dir")}"
    base_ref=$(jq --raw-output '.worktree.baseRef // "fresh"' "$HOME/.claude/settings.json" 2>/dev/null || echo "fresh")

    mkdir -p "$(dirname "$worktree_dir")"

    if git -C "$source_dir" show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo "Creating worktree at $worktree_dir on existing branch $branch_name" >&2
        git -C "$source_dir" worktree add "$worktree_dir" "$branch_name" >&2
    elif [ "$base_ref" = "head" ]; then
        echo "Creating worktree at $worktree_dir on new branch $branch_name from HEAD" >&2
        git -C "$source_dir" worktree add "$worktree_dir" -b "$branch_name" >&2
    else
        default_remote_ref=$(git -C "$source_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo "")
        if [ -z "$default_remote_ref" ]; then
            echo "Creating worktree at $worktree_dir on new branch $branch_name from HEAD (no origin/HEAD found)" >&2
            git -C "$source_dir" worktree add "$worktree_dir" -b "$branch_name" >&2
        else
            echo "Creating worktree at $worktree_dir on new branch $branch_name from $default_remote_ref" >&2
            git -C "$source_dir" worktree add "$worktree_dir" -b "$branch_name" "$default_remote_ref" >&2
        fi
    fi
fi

echo "Copying gitignored files from $source_dir to $worktree_dir" >&2

git -C "$source_dir" ls-files --others --ignored --exclude-standard -z |
    rsync --archive --files-from=- --from0 "$source_dir/" "$worktree_dir/" >&2

if [ -f "$worktree_dir/.envrc" ] && command -v direnv &>/dev/null; then
    echo "Running direnv allow in $worktree_dir" >&2
    direnv allow "$worktree_dir" >&2 || echo "Warning: direnv allow failed" >&2
fi

mise_configs=(".mise.toml" ".mise/config.toml" ".mise.local.toml" ".mise/config.local.toml" "mise.toml")
for config in "${mise_configs[@]}"; do
    if [ -f "$worktree_dir/$config" ] && command -v mise &>/dev/null; then
        echo "Running mise trust in $worktree_dir" >&2
        mise trust "$worktree_dir" >&2 || echo "Warning: mise trust failed" >&2
        break
    fi
done

echo "Worktree setup complete" >&2

# The harness reads our stdout to learn where the worktree landed, so this
# must be the only line on stdout.
echo "$worktree_dir"
