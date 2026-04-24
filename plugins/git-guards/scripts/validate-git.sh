#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

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

# Check for force push to main/master
if [[ "$command" =~ git[[:space:]]+push[[:space:]]+.*--force.*[[:space:]]+(origin[[:space:]]+)?(main|master) ]] ||
    [[ "$command" =~ git[[:space:]]+push[[:space:]]+-f[[:space:]]+.*[[:space:]]+(origin[[:space:]]+)?(main|master) ]]; then
    deny \
        "Force pushing to main/master is extremely dangerous and can cause data loss for collaborators." \
        "If you really need to force push, do it to a feature branch instead, or ask the user to confirm this destructive action"
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
