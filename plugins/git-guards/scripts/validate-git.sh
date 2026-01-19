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

# Check for force push to main/master
if [[ "$command" =~ git[[:space:]]+push[[:space:]]+.*--force.*[[:space:]]+(origin[[:space:]]+)?(main|master) ]] ||
   [[ "$command" =~ git[[:space:]]+push[[:space:]]+-f[[:space:]]+.*[[:space:]]+(origin[[:space:]]+)?(main|master) ]]; then
  cat <<'EOF'
{
  "decision": "deny",
  "reason": "Force pushing to main/master is extremely dangerous and can cause data loss for collaborators.",
  "systemMessage": "If you really need to force push, do it to a feature branch instead, or ask the user to confirm this destructive action"
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
