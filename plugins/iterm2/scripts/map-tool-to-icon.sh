#!/bin/bash

set -euo pipefail

tool_name="${1:-}"

case "$tool_name" in
  Bash)
    echo '$'
    ;;
  Create|Edit|Write|MultiEdit)
    echo '✎'
    ;;
  Read)
    echo '…'
    ;;
  *)
    echo '✻'
    ;;
esac
