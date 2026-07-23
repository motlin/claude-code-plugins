set dotenv-filename := ".envrc"

formatted_shell_scripts := "plugins/*/scripts/*.sh plugins/*/adapters/*.sh test/*.sh test/lib/*.sh install-local.sh"
shellcheck_scripts := `plugins/ratchet/adapters/shellcheck.sh files`

codex_marketplace := "motlin-claude-code-plugins"

# `just --list--unsorted`
default:
    @just --list --unsorted

# ✓ Run automated tests for plugin hooks
test:
    ./test/run-tests.sh

# Run shellcheck, markdownlint, and yamllint
lint:
    shellcheck {{ shellcheck_scripts }}
    markdownlint-cli2
    yamllint --strict .

# Check shell script formatting with shfmt
format:
    shfmt -d -i 4 -ci {{ formatted_shell_scripts }}
    mise exec -- oxfmt --check

# Check every configured ratchet, or one named adapter
ratchet TOOL="":
    @if [ -n "{{TOOL}}" ]; then plugins/ratchet/scripts/ratchet.sh check "{{TOOL}}"; else plugins/ratchet/scripts/ratchet.sh check; fi

# Accept guarded positive decreases for one adapter
ratchet-accept TOOL:
    plugins/ratchet/scripts/ratchet.sh accept "{{TOOL}}"

# Accept a guarded file coverage change for one adapter
ratchet-accept-coverage TOOL:
    plugins/ratchet/scripts/ratchet.sh accept-coverage "{{TOOL}}"

# Promote a zero-count rule into durable enforcement
ratchet-promote TOOL RULE:
    plugins/ratchet/scripts/ratchet.sh promote "{{TOOL}}" "{{RULE}}"

# Run all pre-commit checks
precommit: ratchet format lint test
    pre-commit run --all-files

# Refresh one Codex plugin from the local marketplace and clear its cached copy
codex-reinstall PLUGIN:
    codex plugin remove "{{PLUGIN}}@{{codex_marketplace}}"
    codex plugin add "{{PLUGIN}}@{{codex_marketplace}}"

# 🚀 Create a new release with version bump, commit, tag, and push
release VERSION:
    @if [[ "{{VERSION}}" =~ ^v ]]; then echo "Error: version should not start with 'v' (use '0.18.2' not 'v0.18.2')"; exit 1; fi
    @if ! [[ "{{VERSION}}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Error: invalid version format '{{VERSION}}' (expected X.Y.Z)"; exit 1; fi
    sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' .claude-plugin/marketplace.json
    find plugins -path '*/.claude-plugin/plugin.json' -exec sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' {} \;
    find plugins -path '*/.codex-plugin/plugin.json' -exec sed -i '' 's/"version": "[^"]*"/"version": "{{VERSION}}"/' {} \;
    git add .claude-plugin/marketplace.json plugins/*/.claude-plugin/plugin.json plugins/*/.codex-plugin/plugin.json
    git commit --message "Bump version to {{VERSION}}."
    git tag v{{VERSION}}
    git push && git push --tags
