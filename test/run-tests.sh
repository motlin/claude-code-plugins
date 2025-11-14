#!/bin/bash

set -Eeuo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v bats &> /dev/null; then
  echo "Error: bats is not installed"
  echo "Install with: npm install --global bats"
  exit 1
fi

bats "$script_dir/hooks"/*.bats
