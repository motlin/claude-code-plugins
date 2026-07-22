#!/bin/bash

set -Eeuo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python "$script_dir/ratchet.py" "$@"
