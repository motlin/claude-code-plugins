#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SKILL="$PROJECT_ROOT/plugins/git/skills/reword-commits/SKILL.md"
    export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
    REPO="$BATS_TEST_TMPDIR/repo"
    git init --quiet "$REPO"
    git -C "$REPO" commit --quiet --allow-empty --message "Old subject" --message "Old body line"
}

@test "reword-commits skill command replaces the whole message with one line" {
    command_line="$(rg --no-line-number '^MSG=' "$SKILL")"
    command_line="${command_line//<new single-line message>/New single-line message.}"
    command_line="${command_line//<sha>/HEAD}"

    cd "$REPO"
    run bash -c "$command_line"
    [ "$status" -eq 0 ]

    run git log -1 --format=%B
    [ "$output" = "New single-line message." ]
}
