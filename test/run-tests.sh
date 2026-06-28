#!/bin/bash

set -Eeuo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mise exec -- bats "$script_dir/hooks"/*.bats
mise exec -- bats "$script_dir/scripts"/*.bats
