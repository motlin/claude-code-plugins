#!/bin/bash

set -Eeuo pipefail

indicator="${1:-}"

json=$(cat)
cwd=$(echo "$json" | jq --raw-output '.cwd')
dir_name=$(basename "$cwd")

printf "\e]0;%s %s\a" "$indicator" "$dir_name"
