#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Exit early if no command
if [[ -z "$command" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Check for git add -A or --all (picks up unrelated changes in multi-worktree setups)
if [[ "$command" =~ git[[:space:]]+((-C[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+)[[:space:]]+)?add[[:space:]]+-A ]] ||
    [[ "$command" =~ git[[:space:]]+((-C[[:space:]]+[^[:space:]]+|--git-dir=[^[:space:]]+)[[:space:]]+)?add[[:space:]]+--all ]]; then
    cat <<'EOF'
{
  "decision": "deny",
  "reason": "git add -A is banned because it can pick up unrelated changes when multiple Claude instances are running. Use explicit file paths: git add <file1> <file2> ...",
  "systemMessage": "Run 'git status' to see changed files, then add them individually with 'git add <path>'"
}
EOF
    exit 0
fi

# Check for any push to main/master (regular or force)
if [[ "$command" =~ git[[:space:]]+push.*[[:space:]](main|master)([[:space:]]|$) ]]; then
    cat <<'EOF'
{
  "decision": "deny",
  "reason": "Pushing to main/master is not allowed. Use feature branches and pull requests.",
  "systemMessage": "Create a feature branch and push there instead. Use pull requests to merge into main/master."
}
EOF
    exit 0
fi

# Check for force push without --force-with-lease (on any branch)
if { [[ "$command" =~ git[[:space:]]+push.*--force ]] ||
     [[ "$command" =~ git[[:space:]]+push.*[[:space:]]-[a-zA-Z]*f([[:space:]]|$) ]]; } &&
   ! [[ "$command" =~ --force-with-lease ]]; then
    cat <<'EOF'
{
  "decision": "deny",
  "reason": "Force pushing without --force-with-lease can overwrite others' work.",
  "systemMessage": "Use --force-with-lease instead of --force to safely force push."
}
EOF
    exit 0
fi

# Check for git reset --hard (can lose uncommitted work)
if [[ "$command" =~ git[[:space:]]+reset[[:space:]]+--hard ]]; then
    cat <<'EOF'
{
  "decision": "deny",
  "reason": "git reset --hard discards all uncommitted changes permanently. This is destructive.",
  "systemMessage": "Consider 'git stash' to save changes, or 'git checkout -- <file>' for specific files. If reset is truly needed, ask the user to confirm."
}
EOF
    exit 0
fi

# Check for git clean -fd (deletes untracked files permanently)
if [[ "$command" =~ git[[:space:]]+clean[[:space:]]+-[a-z]*f[a-z]*d ]] ||
    [[ "$command" =~ git[[:space:]]+clean[[:space:]]+-[a-z]*d[a-z]*f ]]; then
    cat <<'EOF'
{
  "decision": "deny",
  "reason": "git clean -fd permanently deletes untracked files. This cannot be undone.",
  "systemMessage": "Use 'git clean -nd' first to preview what would be deleted, then ask the user to confirm before running with -f"
}
EOF
    exit 0
fi

# Allow all other commands
echo '{"decision": "allow"}'
