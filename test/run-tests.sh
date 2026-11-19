#!/bin/bash

set -Eeuo pipefail

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=core.fsmonitor
export GIT_CONFIG_VALUE_0=false

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# `mise exec` rather than a bare `bats`: mise-action puts only the shims
# directory on PATH, and npm-backend tools have no shim there, so a bare `bats`
# resolves under local shell activation but not in GitHub Actions.
mise exec -- bats "$script_dir/hooks"/*.bats
mise exec -- bats "$script_dir/scripts"/*.bats
mise exec -- python3 -m unittest discover -s "$script_dir/../plugins/code/tests"
mise exec -- python3 -m unittest discover -s "$script_dir/../plugins/inline-review/tests"

# The walkthrough suite needs the renderer runtime (Pygments and Astro), which
# setup.py installs at the repository-relative path test_build.py reads.
walkthrough_runtime="$script_dir/../.llm/code-walkthrough"
mise exec -- python3 "$script_dir/../plugins/code-walkthrough/scripts/setup.py" --runtime "$walkthrough_runtime"
"$walkthrough_runtime/.venv/bin/python" -m unittest discover -s "$script_dir/../plugins/code-walkthrough/tests"
