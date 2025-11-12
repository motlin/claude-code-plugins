#!/bin/bash

set -euo pipefail

tmux display-message -p '#{window_name}' | sed 's/^[^ ]* //'
