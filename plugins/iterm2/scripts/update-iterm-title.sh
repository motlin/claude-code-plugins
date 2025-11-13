#!/bin/bash

set -euo pipefail

indicator="${1:-}"
dir_name="${2:-}"

if [ -z "$dir_name" ]; then
  dir_name=$(basename "$PWD")
fi

printf "\e]0;%s %s\a" "$indicator" "$dir_name"
