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
