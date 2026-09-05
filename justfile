# WARNING: this is somewhat dangerous. Direnv's .envrc file contains a few things
# unsupported by dotenv. For instance, "export VAR=1" is unsupported by dotenv.
# In addition, .envrc file that's commonly used by direnv can contain a number of
# direnv-specific functions and statements, such as PATH_add is the direnv function
# to append a folder to a $PATH. You can use in fact any of the functions defined here:
# https://github.com/direnv/direnv/blob/master/stdlib.sh
#
# Note that one of these functions is "dotenv" and "dotenv_if_exists <filename>".
# These last two load your dotenv environment into your shell environment, which is presumably
# what you were trying to accomplish here.
# set dotenv-filename := ".envrc"

formatted_shell_scripts := "plugins/*/scripts/*.sh test/*.sh test/lib/*.sh install-local.sh"
shellcheck_scripts := `plugins/build/scripts/list-shell-files`

codex_marketplace := "motlin-claude-code-plugins"

# `just --list--unsorted`
default:
    @just --list --unsorted

# Install pinned tools
install:
    mise install

# ✓ Run automated tests for plugin hooks
test: install
    ./test/run-tests.sh

# Run shellcheck, markdownlint, and yamllint
lint: install
    shellcheck --external-sources {{ shellcheck_scripts }}
    markdownlint-cli2
    yamllint --strict .

# Check shell script formatting with shfmt
format: install
    shfmt -d -i 4 -ci {{ formatted_shell_scripts }}
    oxfmt --check

# Run configured pre-commit hooks on every tracked file
pre-commit: install
    pre-commit run --all-files

# Run all pre-commit checks
precommit: format lint test pre-commit

# Refresh one Codex plugin from the local marketplace and clear its cached copy
[arg("PLUGIN", long="plugin", help="Plugin name")]
codex-reinstall PLUGIN:
    codex plugin remove "{{ PLUGIN }}@{{ codex_marketplace }}"
    codex plugin add "{{ PLUGIN }}@{{ codex_marketplace }}"

# 🚀 Create a new release with version bump, commit, tag, and push
[arg("VERSION", long="version", help="Release version")]
release VERSION:
    @if [[ "{{ VERSION }}" =~ ^v ]]; then echo "Error: version should not start with 'v' (use '0.18.2' not 'v0.18.2')"; exit 1; fi
    @if ! [[ "{{ VERSION }}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Error: invalid version format '{{ VERSION }}' (expected X.Y.Z)"; exit 1; fi
    sed -i '' 's/"version": "[^"]*"/"version": "{{ VERSION }}"/' .claude-plugin/marketplace.json
    find plugins -path '*/.claude-plugin/plugin.json' -exec sed -i '' 's/"version": "[^"]*"/"version": "{{ VERSION }}"/' {} \;
    find plugins -path '*/.codex-plugin/plugin.json' -exec sed -i '' 's/"version": "[^"]*"/"version": "{{ VERSION }}"/' {} \;
    git add .claude-plugin/marketplace.json plugins/*/.claude-plugin/plugin.json plugins/*/.codex-plugin/plugin.json
    git commit --message "Bump version to {{ VERSION }}."
    git tag v{{ VERSION }}
    git push && git push --tags
