#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SKILL="$PROJECT_ROOT/plugins/git/skills/commit/SKILL.md"
}

@test "commit skill forbids amending after a hook failure" {
    run rg --fixed-strings 'Never run `git commit --amend`' "$SKILL"
    [ "$status" -eq 0 ]
}

@test "commit skill repairs an earlier commit with a new or fixup commit" {
    run rg --fixed-strings 'git commit --fixup <sha>' "$SKILL"
    [ "$status" -eq 0 ]
}
