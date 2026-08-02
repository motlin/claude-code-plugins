#!/bin/bash

set -Eeuo pipefail

claude_config_directory="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
managed_hook="$claude_config_directory/hooks/herdr-agent-state.sh"

if [ ! -f "$managed_hook" ]; then
    exit 0
fi

exec bash "$managed_hook" session
