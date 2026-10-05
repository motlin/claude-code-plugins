#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export UPSTREAM_REMOTE=origin UPSTREAM_BRANCH=main GIT_TESTS=example
    export TEST_LOG="$BATS_TEST_TMPDIR/test-arguments"
    export HOOK_LOG="$BATS_TEST_TMPDIR/hook-arguments"
    export FORMAT_MARKER="$BATS_TEST_TMPDIR/formatted"
    export HOOK_MODE=pass HOOK_EXIT=0 TEST_EXIT=0
    REPOSITORY="$BATS_TEST_TMPDIR/repository"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    cat >"$BATS_TEST_TMPDIR/bin/git-test" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TEST_LOG"
exit "${TEST_EXIT:-0}"
SCRIPT
    cat >"$BATS_TEST_TMPDIR/bin/uv" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$HOOK_LOG"
if [ "${HOOK_MODE:-pass}" = format ] && [ ! -f "$FORMAT_MARKER" ]; then
    printf 'formatted\n' >'first file.txt'
    touch "$FORMAT_MARKER"
    exit 1
fi
exit "${HOOK_EXIT:-0}"
SCRIPT
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    git init --quiet --initial-branch=main "$REPOSITORY"
    cd "$REPOSITORY" || return
    git config user.name 'Alice Example'
    git config user.email alice@example.com
    printf 'JUSTFILE_BRANCH\n' >.gitignore
    printf 'base\n' >base.txt
    git add .gitignore base.txt
    git commit --quiet --message 'Add base.'
    BASE=$(git rev-parse HEAD)
    git update-ref refs/remotes/origin/main HEAD
    git switch --quiet --create feature
    printf 'broken\n' >'first file.txt'
    printf 'broken\n' >second.txt
    git add 'first file.txt' second.txt
    git commit --quiet --message 'Add feature.'
    FAILING=$(git rev-parse HEAD)
    git branch other "$FAILING"
    printf 'feature\n' >JUSTFILE_BRANCH
}

run_branch() {
    run "$PROJECT_ROOT/plugins/build/scripts/test-branch" "$@"
}

repair() {
    git switch --quiet --detach "$FAILING"
    printf 'fixed\n' >'first file.txt'
    printf 'fixed\n' >second.txt
}

run_fix() {
    run env "$@" "$PROJECT_ROOT/plugins/build/scripts/test-fix"
}

@test "one branch argument keeps default test flags" {
    run_branch feature
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_LOG")" = $'run\n--tests\nexample\n--retest\n--verbose\n--verbose\norigin/main..feature' ]
    [ "$(cat JUSTFILE_BRANCH)" = feature ]
}

@test "test names and explicit flags retain argument boundaries" {
    run_branch feature 'example suite' --keep-going --verbose
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_LOG")" = $'run\n--tests\nexample suite\n--keep-going\n--verbose\norigin/main..feature' ]
}

@test "detached default invocation preserves the saved branch" {
    git switch --quiet --detach
    run_branch
    [ "$status" -eq 2 ]
    [ "$output" = 'Detached HEAD: pass the original branch explicitly; JUSTFILE_BRANCH was not changed.' ]
    [ "$(cat JUSTFILE_BRANCH)" = feature ]
    [ ! -e "$TEST_LOG" ]
}

@test "explicit original branch can be retested from detached HEAD" {
    git switch --quiet --detach
    run_branch feature
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_LOG")" = $'run\n--tests\nexample\n--retest\n--verbose\n--verbose\norigin/main..feature' ]
}

@test "invalid branch leaves saved target untouched" {
    run_branch missing
    [ "$status" -ne 0 ]
    [ "$(cat JUSTFILE_BRANCH)" = feature ]
    [ ! -e "$TEST_LOG" ]
}

@test "tip repair passes spaced filenames separately and preserves other refs" {
    repair
    run_fix
    [ "$status" -eq 0 ]
    [ "$(cat "$HOOK_LOG")" = $'tool\nrun\npre-commit\nrun\n--files\nfirst file.txt\nsecond.txt' ]
    [ "$(cat "$TEST_LOG")" = $'run\n--tests\nexample\n--retest\n--verbose\n--verbose\norigin/main..feature' ]
    [ "$(git log --format=%s "$BASE..feature")" = 'Add feature.' ]
    [ "$(git show 'feature:first file.txt')" = fixed ]
    [ "$(git rev-parse other)" = "$FAILING" ]
    [ "$(git branch --show-current)" = feature ]
    [ "$(git status --porcelain)" = '' ]
}

@test "repair replays descendants without rebasing onto a diverged upstream" {
    printf 'descendant\n' >later.txt
    git add later.txt
    git commit --quiet --message 'Add descendant.'
    git switch --quiet main
    printf 'upstream\n' >upstream.txt
    git add upstream.txt
    git commit --quiet --message 'Add upstream.'
    git update-ref refs/remotes/origin/main HEAD
    repair
    run_fix
    [ "$status" -eq 0 ]
    [ "$(git log --reverse --format=%s "$BASE..feature")" = $'Add feature.\nAdd descendant.' ]
    [ "$(git show feature:later.txt)" = descendant ]
    [ "$(git show 'feature:first file.txt')" = fixed ]
    [ "$(git merge-base origin/main feature)" = "$BASE" ]
    [ "$(git rev-parse other)" = "$FAILING" ]
    [ "$(git status --porcelain)" = '' ]
}

@test "formatter edits get one hook retry before committing" {
    repair
    run_fix HOOK_MODE=format
    [ "$status" -eq 0 ]
    [ "$(git show 'feature:first file.txt')" = formatted ]
    [ "$(git status --porcelain)" = '' ]
}

@test "persistent hook failure never creates a repair commit or starts retesting" {
    repair
    run_fix HOOK_EXIT=1
    [ "$status" -eq 2 ]
    [ "$output" = 'Pre-commit failed without formatting changes; no repair commit was created.' ]
    [ "$(git rev-parse HEAD)" = "$FAILING" ]
    [ "$(git rev-parse feature)" = "$FAILING" ]
    [ "$(git diff --cached --name-only)" = $'first file.txt\nsecond.txt' ]
    [ ! -e "$TEST_LOG" ]
}

@test "failure after formatting also stops before creating a repair commit" {
    repair
    run_fix HOOK_MODE=format HOOK_EXIT=1
    [ "$status" -eq 2 ]
    [ "$output" = 'test-fix failed during pre-commit hooks; stopped before retesting. Inspect Git state before retrying.' ]
    [ "$(git rev-parse HEAD)" = "$FAILING" ]
    [ ! -e "$TEST_LOG" ]
}

@test "commit hooks are not bypassed" {
    repair
    printf '#!/bin/sh\nexit 1\n' >.git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    run_fix
    [ "$status" -eq 2 ]
    [ "$output" = 'test-fix failed during repair commit; stopped before retesting. Inspect Git state before retrying.' ]
    [ "$(git rev-parse HEAD)" = "$FAILING" ]
    [ ! -e "$TEST_LOG" ]
}

@test "replay conflict is a workflow failure and retains branch and detached repair" {
    printf 'later change\n' >'first file.txt'
    git add 'first file.txt'
    git commit --quiet --message 'Change feature.'
    original_tip=$(git rev-parse feature)
    repair
    run_fix
    [ "$status" -eq 2 ]
    [ "${lines[${#lines[@]} - 1]}" = 'test-fix failed during replay; stopped before retesting. Inspect Git state before retrying.' ]
    [ "$(git rev-parse feature)" = "$original_tip" ]
    [ "$(git log -1 --format=%s)" = 'Add feature.' ]
    [ "$(git show 'HEAD:first file.txt')" = fixed ]
    [ "$(cat JUSTFILE_BRANCH)" = feature ]
    [ ! -e "$TEST_LOG" ]
}

@test "repair preserves preexisting descendant fixup commits" {
    printf 'descendant\n' >later.txt
    git add later.txt
    git commit --quiet --message 'Add descendant.'
    descendant=$(git rev-parse HEAD)
    printf 'revised\n' >later.txt
    git add later.txt
    git commit --quiet --fixup "$descendant"
    repair
    run_fix
    [ "$status" -eq 0 ]
    [ "$(git log --reverse --format=%s "$BASE..feature")" = $'Add feature.\nAdd descendant.\nfixup! Add descendant.' ]
    [ "$(git show feature:later.txt)" = revised ]
    [ "$(git show 'feature:first file.txt')" = fixed ]
    [ "$(git status --porcelain)" = '' ]
}

@test "repair can leave the original failing commit empty" {
    git switch --quiet --detach "$FAILING"
    rm 'first file.txt' second.txt
    run_fix
    [ "$status" -eq 0 ]
    [ "$(git log --format=%s "$BASE..feature")" = 'Add feature.' ]
    [ "$(git rev-parse 'feature^{tree}')" = "$(git rev-parse "$BASE^{tree}")" ]
    [ "$(git status --porcelain)" = '' ]
}

@test "failed retest keeps its exit status and original branch marker" {
    repair
    run_fix TEST_EXIT=1
    [ "$status" -eq 1 ]
    [ "$(cat JUSTFILE_BRANCH)" = feature ]
    [ "$(git log --format=%s "$BASE..feature")" = 'Add feature.' ]
    [ "$(cat "$TEST_LOG")" = $'run\n--tests\nexample\n--retest\n--verbose\n--verbose\norigin/main..feature' ]
}
