#!/bin/bash

set -Eeuo pipefail

adapter_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python "$adapter_dir/lint_adapter.py" yamllint "$@"
