set dotenv-filename := ".envrc"

# `just --list--unsorted`
default:
    @just --list --unsorted

# ✓ Run automated tests for plugin hooks
test:
    ./test/run-tests.sh

# Run all formatting tools for pre-commit
precommit: test

# 🚀 Create a new release with version bump, commit, tag, and push
release VERSION:
    @if [[ "{{VERSION}}" =~ ^v ]]; then echo "Error: version should not start with 'v' (use '0.18.2' not 'v0.18.2')"; exit 1; fi
    @if ! [[ "{{VERSION}}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Error: invalid version format '{{VERSION}}' (expected X.Y.Z)"; exit 1; fi
    sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' .claude-plugin/marketplace.json
    find plugins -path '*/.claude-plugin/plugin.json' -exec sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' {} \;
    git add .claude-plugin/marketplace.json plugins/*/.claude-plugin/plugin.json
    git commit --message "Bump version to {{VERSION}}."
    git tag v{{VERSION}}
    git push && git push --tags
