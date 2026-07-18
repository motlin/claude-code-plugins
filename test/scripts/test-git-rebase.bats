#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    REPOSITORY="$BATS_TEST_TMPDIR/repository"
    SEQUENCE_EDITOR="$BATS_TEST_TMPDIR/sequence-editor"

    git init --quiet --initial-branch=main "$REPOSITORY"
    git -C "$REPOSITORY" config user.name "Alice Example"
    git -C "$REPOSITORY" config user.email "alice@example.com"

    printf 'base\n' >"$REPOSITORY/base.txt"
    git -C "$REPOSITORY" add base.txt
    git -C "$REPOSITORY" commit --quiet --message "Add base."
    base_commit="$(git -C "$REPOSITORY" rev-parse HEAD)"

    git -C "$REPOSITORY" branch feature "$base_commit"
    printf 'upstream\n' >"$REPOSITORY/upstream.txt"
    git -C "$REPOSITORY" add upstream.txt
    git -C "$REPOSITORY" commit --quiet --message "Add upstream change."
    git -C "$REPOSITORY" update-ref refs/remotes/origin/main HEAD

    git -C "$REPOSITORY" switch --quiet feature
    printf 'feature\n' >"$REPOSITORY/feature.txt"
    git -C "$REPOSITORY" add feature.txt
    git -C "$REPOSITORY" commit --quiet --message "Add feature change."

    printf '#!/usr/bin/env bash\nexit 99\n' >"$SEQUENCE_EDITOR"
    chmod +x "$SEQUENCE_EDITOR"
}

@test "rebase does not open the sequence editor" {
    run env OFFLINE=true UPSTREAM_REMOTE=origin UPSTREAM_BRANCH=main \
        GIT_SEQUENCE_EDITOR="$SEQUENCE_EDITOR" \
        bash -c 'command cd "$1"
            exec "$2"' bash "$REPOSITORY" "$PROJECT_ROOT/plugins/git/scripts/rebase"

    [ "$status" -eq 0 ]
    [[ "$output" == *"git rebase --autosquash --rebase-merges --update-refs origin/main"* ]]
    [ "$(git -C "$REPOSITORY" merge-base origin/main HEAD)" = \
        "$(git -C "$REPOSITORY" rev-parse origin/main)" ]
}

@test "rebase rejects arguments" {
    run "$PROJECT_ROOT/plugins/git/scripts/rebase" --interactive

    [ "$status" -eq 2 ]
    [ "$output" = "Usage: rebase" ]
}
