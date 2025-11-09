set dotenv-filename := ".envrc"

# `just --list--unsorted`
default:
    @just --list --unsorted

# 🚀 Create a new release with version bump, commit, tag, and push
release VERSION:
    sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' plugins/markdown-tasks/.claude-plugin/plugin.json
    sed -i '' '/"name": "markdown-tasks"/,/"source":/ s/"version": "[^"]*"/"version": "{{VERSION}}"/' .claude-plugin/marketplace.json
    git add plugins/markdown-tasks/.claude-plugin/plugin.json .claude-plugin/marketplace.json
    git commit --message "Bump version to {{VERSION}}."
    git tag v{{VERSION}}
    git push && git push --tags
