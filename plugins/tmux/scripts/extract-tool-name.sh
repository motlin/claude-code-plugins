#!/bin/bash

set -euo pipefail

jq --raw-output '.tool_name // ""'
