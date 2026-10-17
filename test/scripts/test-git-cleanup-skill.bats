#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SKILL="$PROJECT_ROOT/plugins/git/skills/git-cleanup/SKILL.md"
}

@test "git-cleanup skill is named git-cleanup" {
    run rg --fixed-strings "name: git-cleanup" "$SKILL"
    [ "$status" -eq 0 ]
}

@test "git-cleanup skill is listed in the git plugin README" {
    run rg --fixed-strings '`/git:git-cleanup`' "$PROJECT_ROOT/plugins/git/README.md"
    [ "$status" -eq 0 ]
}

@test "git-cleanup skill rebases through the rebase-all skill" {
    run rg --fixed-strings "git:rebase-all" "$SKILL"
    [ "$status" -eq 0 ]
}

@test "git-cleanup skill points UPSTREAM_REMOTE at origin in .envrc when upstream is missing" {
    run rg --fixed-strings 'export UPSTREAM_REMOTE=origin' "$SKILL"
    [ "$status" -eq 0 ]
}

@test "git-cleanup skill offers .git/info/exclude for local-only files" {
    run rg --fixed-strings ".git/info/exclude" "$SKILL"
    [ "$status" -eq 0 ]
}

@test "git-cleanup skill asks before delete-merged" {
    run rg --fixed-strings "Ask the user before running" "$SKILL"
    [ "$status" -eq 0 ]
}

# A checkout during a stopped rebase carries the rebase onto the new branch, and
# the next --continue commits there.
@test "git-cleanup skill forbids switching branches while a rebase is stopped" {
    run rg --fixed-strings "Never switch branches while a rebase is stopped" "$SKILL"
    [ "$status" -eq 0 ]
}

# rebase-all skips branches checked out in other worktrees, so removing the
# worktrees first lets their branches be rebased.
@test "git-cleanup skill removes worktrees through clean-worktrees before rebasing" {
    run rg --fixed-strings "git:clean-worktrees" "$SKILL"
    [ "$status" -eq 0 ]
    worktrees_line="$(rg --line-number --fixed-strings "git:clean-worktrees" "$SKILL" | head -1 | cut -d: -f1)"
    rebase_line="$(rg --line-number --fixed-strings "Rebase with the \`git:rebase-all\` skill" "$SKILL" | cut -d: -f1)"
    [ "$worktrees_line" -lt "$rebase_line" ]
}

@test "git-cleanup skill never removes worktrees with --force" {
    run rg --fixed-strings "never \`--force\`" "$SKILL"
    [ "$status" -eq 0 ]
}
