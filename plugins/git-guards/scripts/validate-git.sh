#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

deny() {
    local reason="$1"
    local message="$2"
    jq --null-input \
        --arg reason "$reason" \
        --arg message "$message" \
        '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason
            },
            systemMessage: $message
        }'
    exit 0
}

# Exit early if no command
if [[ -z "$command" ]]; then
    exit 0
fi

# Check for git add -A or --all (picks up unrelated changes in multi-worktree setups)
if [[ "$command" =~ git[[:space:]]+((-C[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+)[[:space:]]+)?add[[:space:]]+-A ]] ||
    [[ "$command" =~ git[[:space:]]+((-C[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+)[[:space:]]+)?add[[:space:]]+--all ]]; then
    deny \
        "git add -A is banned because it can pick up unrelated changes when multiple Claude instances are running. Use explicit file paths: git add <file1> <file2> ..." \
        "Run 'git status' to see changed files, then add them individually with 'git add <path>'"
fi

# Check for any push to main/master (regular or force)
if [[ "$command" =~ git[[:space:]]+push.*[[:space:]](main|master)([[:space:]]|$) ]]; then
    deny \
        "Pushing to main/master is not allowed. Use feature branches and pull requests." \
        "Create a feature branch and push there instead. Use pull requests to merge into main/master."
fi

# Check for pushes that reach main/master without naming it: bare `git push`,
# `git push origin HEAD`, `git -C <dir> push`, and refspecs like `feature:main`.
# The text-only check above misses these because the command never says "main".
if [[ "$command" =~ git[[:space:]]+(-C[[:space:]]+([^[:space:]]+)[[:space:]]+)?push([[:space:]]|$) ]]; then
    git_c_dir="${BASH_REMATCH[2]}"

    # Take everything after "push", truncated at shell operators
    push_args="${command#*push}"
    push_args="${push_args%%|*}"
    push_args="${push_args%%;*}"
    push_args="${push_args%%&&*}"

    # The refspec is the second positional arg (after the remote), skipping
    # flags and redirections
    refspec=""
    positional_count=0
    for word in $push_args; do
        case "$word" in
            -*) continue ;;
            *'>'*) continue ;;
            *)
                positional_count=$((positional_count + 1))
                if [[ "$positional_count" -eq 2 ]]; then
                    refspec="$word"
                fi
                ;;
        esac
    done

    # Refspec whose destination is main/master (e.g. my-feature:main)
    if [[ "$refspec" =~ :(main|master)$ ]]; then
        deny \
            "Pushing to main/master is not allowed. Use feature branches and pull requests." \
            "Create a feature branch and push there instead. Use pull requests to merge into main/master."
    fi

    # No refspec (or HEAD): the push targets the current branch
    if [[ -z "$refspec" || "$refspec" == "HEAD" ]]; then
        git_args=()
        if [[ -n "$cwd" ]]; then git_args+=(-C "$cwd"); fi
        if [[ -n "$git_c_dir" ]]; then git_args+=(-C "$git_c_dir"); fi
        branch=$(git ${git_args[@]+"${git_args[@]}"} symbolic-ref --quiet --short HEAD 2>/dev/null || true)
        if [[ "$branch" == "main" || "$branch" == "master" ]]; then
            deny \
                "This push targets the current branch, which is $branch. Pushing to main/master is not allowed. Use feature branches and pull requests." \
                "Create a feature branch and push there instead. Use pull requests to merge into main/master."
        fi
    fi
fi

# Check for force push without --force-with-lease (on any branch)
if { [[ "$command" =~ git[[:space:]]+push.*--force ]] ||
    [[ "$command" =~ git[[:space:]]+push.*[[:space:]]-[a-zA-Z]*f([[:space:]]|$) ]]; } &&
    ! [[ "$command" =~ --force-with-lease ]]; then
    deny \
        "Force pushing without --force-with-lease can overwrite others' work." \
        "Use --force-with-lease instead of --force to safely force push."
fi

# Check for git reset --hard (can lose uncommitted work)
if [[ "$command" =~ git[[:space:]]+reset[[:space:]]+--hard ]]; then
    deny \
        "git reset --hard discards all uncommitted changes permanently. This is destructive." \
        "Consider 'git stash' to save changes, or 'git checkout -- <file>' for specific files. If reset is truly needed, ask the user to confirm."
fi

# Check for git clean -fd (deletes untracked files permanently)
if [[ "$command" =~ git[[:space:]]+clean[[:space:]]+-[a-z]*f[a-z]*d ]] ||
    [[ "$command" =~ git[[:space:]]+clean[[:space:]]+-[a-z]*d[a-z]*f ]]; then
    deny \
        "git clean -fd permanently deletes untracked files. This cannot be undone." \
        "Use 'git clean -nd' first to preview what would be deleted, then ask the user to confirm before running with -f"
fi
