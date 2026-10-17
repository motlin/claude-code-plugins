#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SKILL="$PROJECT_ROOT/plugins/git/skills/rebase-all/SKILL.md"
}

# git-all chains delete-merged, which deletes remote branches without asking.
@test "rebase-all skill does not run git-all" {
    run rg --fixed-strings "scripts/git-all" "$SKILL"
    [ "$status" -eq 1 ]
}

@test "rebase-all skill runs the rebase-only script" {
    run rg --fixed-strings "<plugin-root>/scripts/rebase-all" "$SKILL"
    [ "$status" -eq 0 ]
}

@test "rebase-all skill asks before delete-merged" {
    run rg --fixed-strings "Ask the user before running" "$SKILL"
    [ "$status" -eq 0 ]
}

@test "rebase-all skill says the script replays before it rebases" {
    run rg --fixed-strings "replay-all" "$SKILL"
    [ "$status" -eq 0 ]
}
