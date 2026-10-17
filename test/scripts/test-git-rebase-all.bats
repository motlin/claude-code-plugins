#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPTS="$PROJECT_ROOT/plugins/git/scripts"
    REPOSITORY="$BATS_TEST_TMPDIR/repository"

    git init --quiet --initial-branch=main "$REPOSITORY"
    git -C "$REPOSITORY" config user.name "Alice Example"
    git -C "$REPOSITORY" config user.email "alice@example.com"

    printf 'base\n' >"$REPOSITORY/base.txt"
    git -C "$REPOSITORY" add base.txt
    git -C "$REPOSITORY" commit --quiet --message "Add base."
    base_commit="$(git -C "$REPOSITORY" rev-parse HEAD)"

    printf 'upstream\n' >"$REPOSITORY/base.txt"
    git -C "$REPOSITORY" commit --quiet --all --message "Change base upstream."
    git -C "$REPOSITORY" update-ref refs/remotes/origin/main HEAD
}

# Commits FILE with CONTENT on a new BRANCH that starts at START.
commit_on_branch() {
    local branch="$1" start="$2" file="$3" content="$4"
    git -C "$REPOSITORY" branch "$branch" "$start"
    git -C "$REPOSITORY" switch --quiet "$branch"
    printf '%s\n' "$content" >"$REPOSITORY/$file"
    git -C "$REPOSITORY" add "$file"
    git -C "$REPOSITORY" commit --quiet --message "Change $file on $branch."
    git -C "$REPOSITORY" switch --quiet main
}

run_script() {
    # shellcheck disable=SC2016
    run env OFFLINE=true UPSTREAM_REMOTE=origin UPSTREAM_BRANCH=main \
        bash -c 'command cd "$1"
            exec "$2"' bash "$REPOSITORY" "$SCRIPTS/$1"
}

is_on_origin_main() {
    git -C "$REPOSITORY" merge-base --is-ancestor origin/main "$1"
}

@test "rebase-all replays clean branches without checking them out" {
    commit_on_branch clean "$base_commit" clean.txt clean

    run_script rebase-all

    [ "$status" -eq 0 ]
    [[ "$output" == *"Replaying branch clean onto origin/main"* ]]
    [[ "$output" != *"Rebasing branch clean"* ]]
    [ "$(git -C "$REPOSITORY" symbolic-ref --short HEAD)" = "main" ]
    is_on_origin_main clean
}

@test "rebase-all falls back to rebase for a branch that replay cannot apply" {
    commit_on_branch conflicting "$base_commit" base.txt conflicting

    run_script rebase-all

    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to replay branch conflicting"* ]]
    [[ "$output" == *"Rebasing branch conflicting onto origin/main"* ]]
    [ -d "$(git -C "$REPOSITORY" rev-parse --absolute-git-dir)/rebase-merge" ]
}

@test "replay-all moves every branch in a stack" {
    commit_on_branch lower "$base_commit" lower.txt lower
    commit_on_branch upper lower upper.txt upper

    run_script replay-all

    [ "$status" -eq 0 ]
    is_on_origin_main lower
    is_on_origin_main upper
    [ "$(git -C "$REPOSITORY" rev-parse upper~1)" = "$(git -C "$REPOSITORY" rev-parse lower)" ]
}

# git replay moves refs without touching the checkout, which would leave that
# checkout with upstream's changes reversed and staged.
@test "replay-all skips a stack with a branch checked out in a worktree" {
    commit_on_branch busy "$base_commit" busy.txt busy
    busy_commit="$(git -C "$REPOSITORY" rev-parse busy)"
    git -C "$REPOSITORY" worktree add --quiet "$BATS_TEST_TMPDIR/busy" busy

    run_script replay-all

    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping branch busy as busy is checked out"* ]]
    [ "$(git -C "$REPOSITORY" rev-parse busy)" = "$busy_commit" ]
}

@test "replay-all reports every failed branch and exits non-zero" {
    commit_on_branch conflicting "$base_commit" base.txt conflicting
    commit_on_branch clean "$base_commit" clean.txt clean

    run_script replay-all

    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to replay branch conflicting"* ]]
    is_on_origin_main clean
}

@test "replay-all with KEEP_GOING exits zero after a failed branch" {
    commit_on_branch conflicting "$base_commit" base.txt conflicting

    # shellcheck disable=SC2016
    run env OFFLINE=true UPSTREAM_REMOTE=origin UPSTREAM_BRANCH=main KEEP_GOING=true \
        bash -c 'command cd "$1"
            exec "$2"' bash "$REPOSITORY" "$SCRIPTS/replay-all"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Failed to replay branch conflicting"* ]]
}
