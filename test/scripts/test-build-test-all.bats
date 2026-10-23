#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export TEST_BRANCH_LOG="$BATS_TEST_TMPDIR/branches.log"
    export UPSTREAM_REMOTE=upstream UPSTREAM_BRANCH=main
    unset FAIL_FAST
    mkdir "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    cat >"$BATS_TEST_TMPDIR/bin/git" <<'SCRIPT'
#!/usr/bin/env bash
case "$1" in
    for-each-ref)
        printf 'branch-alice\nbranch-bob\n'
        ;;
    show-ref | rev-parse) ;;
    test)
        printf '%s\n' "$*" >>"$TEST_BRANCH_LOG"
        if [[ "${*: -1}" = upstream/main..branch-alice && "${FAIL_BRANCH_ALICE:-false}" = true ]]; then
            exit 7
        fi
        ;;
    *) exit 99 ;;
esac
SCRIPT
    chmod +x "$BATS_TEST_TMPDIR/bin/git"
    command cd "$BATS_TEST_TMPDIR" || return
}

@test "test-all reports failure after testing the remaining branches by default" {
    run env FAIL_BRANCH_ALICE=true "$PROJECT_ROOT/plugins/build/scripts/test-all" default

    [ "$status" -eq 7 ]
    [ "$(cat "$TEST_BRANCH_LOG")" = 'test run --tests default --retest --verbose --verbose upstream/main..branch-alice
test run --tests default --retest --verbose --verbose upstream/main..branch-bob' ]
}

@test "test-all succeeds when every branch passes" {
    run env FAIL_BRANCH_ALICE=false "$PROJECT_ROOT/plugins/build/scripts/test-all" default

    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_BRANCH_LOG")" = 'test run --tests default --retest --verbose --verbose upstream/main..branch-alice
test run --tests default --retest --verbose --verbose upstream/main..branch-bob' ]
}

@test "test-all stops at the first failure when FAIL_FAST is true" {
    run env FAIL_FAST=true FAIL_BRANCH_ALICE=true "$PROJECT_ROOT/plugins/build/scripts/test-all" default

    [ "$status" -eq 7 ]
    [ "$(cat "$TEST_BRANCH_LOG")" = 'test run --tests default --retest --verbose --verbose upstream/main..branch-alice' ]
}

@test "test-all tests every passing branch when FAIL_FAST is true" {
    run env FAIL_FAST=true FAIL_BRANCH_ALICE=false "$PROJECT_ROOT/plugins/build/scripts/test-all" default

    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_BRANCH_LOG")" = 'test run --tests default --retest --verbose --verbose upstream/main..branch-alice
test run --tests default --retest --verbose --verbose upstream/main..branch-bob' ]
}
