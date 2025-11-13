set dotenv-filename := ".envrc"

# `just --list--unsorted`
default:
    @just --list --unsorted

# 🚀 Create a new release with version bump, commit, tag, and push
release VERSION:
    sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' .claude-plugin/marketplace.json
    find plugins -path '*/.claude-plugin/plugin.json' -exec sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' {} \;
    git add .claude-plugin/marketplace.json plugins/*/.claude-plugin/plugin.json
    git commit --message "Bump version to {{VERSION}}."
    git tag v{{VERSION}}
    git push && git push --tags
