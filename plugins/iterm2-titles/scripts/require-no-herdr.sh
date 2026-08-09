#!/bin/bash

set -Eeuo pipefail

cat >/dev/null

if [ "${HERDR_ENV:-}" != "1" ]; then
    exit 0
fi

cat >&2 <<'MESSAGE'
iterm2-titles is running inside herdr, where it breaks agent status reporting.

The plugin sets CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 and writes its own terminal
title. herdr reads that title to tell a working Claude agent from an idle one --
a braille spinner means working, U+2733 means idle -- so every pane reports idle
and the sidebar stays green while Claude works.

Disable iterm2-titles, or run Claude outside herdr.
MESSAGE
exit 2
