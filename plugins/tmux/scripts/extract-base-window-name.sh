#!/bin/bash

set -euo pipefail

jq --raw-output '.cwd // ""' | xargs basename
