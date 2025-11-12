#!/bin/bash

set -euo pipefail

indicator="${1:-}"
dir_name="${2:-}"

if [ -z "${TMUX:-}" ]; then
  exit 0
fi

if [ -z "$dir_name" ]; then
  dir_name=$(basename "$PWD")
fi

tmux rename-window "$indicator $dir_name"
