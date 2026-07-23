#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    REPOSITORY="$BATS_TEST_TMPDIR/shell-file-discovery"
    mkdir -p "$REPOSITORY"
    git -C "$REPOSITORY" init --quiet
}

@test "shell file discovery includes Bash and Bats shebangs" {
    printf '#!/usr/bin/env bash\n' >"$REPOSITORY/extensionless-script"
    printf '#!/bin/bash\n' >"$REPOSITORY/script.sh"
    printf '#!/usr/bin/env bats\n' >"$REPOSITORY/script.bats"
    printf '#!/usr/bin/env python3\n' >"$REPOSITORY/script.py"

    run bash -c 'command cd "$1" && "$2"' _ \
        "$REPOSITORY" "$PROJECT_ROOT/plugins/build/scripts/list-shell-files"

    [ "$status" -eq 0 ]
    [ "$output" = "extensionless-script script.bats script.sh " ]
}
