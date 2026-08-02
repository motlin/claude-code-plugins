#!/bin/bash

set -Eeuo pipefail

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=core.fsmonitor
export GIT_CONFIG_VALUE_0=false

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bats "$script_dir/hooks"/*.bats
bats "$script_dir/scripts"/*.bats
