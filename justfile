set dotenv-filename := ".envrc"

# `just --list--unsorted`
default:
    @just --list --unsorted

# 🚀 Create a new release with version bump, commit, tag, and push
release VERSION:
    sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' .claude-plugin/marketplace.json
    sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' plugins/markdown-tasks/.claude-plugin/plugin.json
    sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' plugins/tmux/.claude-plugin/plugin.json
    sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' plugins/git-worktree/.claude-plugin/plugin.json
    git add .claude-plugin/marketplace.json plugins/markdown-tasks/.claude-plugin/plugin.json plugins/tmux/.claude-plugin/plugin.json plugins/git-worktree/.claude-plugin/plugin.json
    git commit --message "Bump version to {{VERSION}}."
    git tag v{{VERSION}}
    git push && git push --tags
