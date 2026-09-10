#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(command cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    REPOSITORY="$BATS_TEST_TMPDIR/repository"
    WORKTREE="$BATS_TEST_TMPDIR/repository-feature"
    EXPECTED="$BATS_TEST_TMPDIR/expected"
    mkdir -p "$EXPECTED" "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$BATS_TEST_TMPDIR/bin/mise"
    chmod +x "$BATS_TEST_TMPDIR/bin/mise"

    git init --quiet --initial-branch=main "$REPOSITORY"
    git -C "$REPOSITORY" config user.name "Alice Example"
    git -C "$REPOSITORY" config user.email "alice@example.com"
    git -C "$REPOSITORY" -c core.hooksPath=/dev/null commit --quiet --allow-empty --message "Add base."
    git -C "$REPOSITORY" update-ref refs/remotes/origin/main HEAD
}

create_worktree() {
    # shellcheck disable=SC2016
    run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" UPSTREAM_REMOTE=origin UPSTREAM_BRANCH=main \
        bash -c 'command cd "$1"
            exec "$2" feature' bash "$REPOSITORY" "$PROJECT_ROOT/plugins/git/scripts/worktree.sh"
    [ "$status" -eq 0 ]
}

create_local_configuration() {
    mkdir -p "$REPOSITORY/.codex/hooks" "$REPOSITORY/.codex/agents"
    printf 'model = "test-model"\n' >"$REPOSITORY/.codex/config.toml"
    printf '#!/usr/bin/env bash\nprintf "test hook\\n"\n' >"$REPOSITORY/.codex/hooks/test-hook.sh"
    chmod +x "$REPOSITORY/.codex/hooks/test-hook.sh"
    printf 'description = "Test agent"\n' >"$REPOSITORY/.codex/agents/test-agent.toml"
    cp -R "$REPOSITORY/.codex/." "$EXPECTED/"
}

@test "worktree carries untracked Codex configuration and executable hooks" {
    create_local_configuration

    create_worktree

    run diff -r "$EXPECTED" "$WORKTREE/.codex"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    [ -x "$WORKTREE/.codex/hooks/test-hook.sh" ]
}

@test "worktree carries ignored Codex configuration" {
    printf '.codex/\n' >"$REPOSITORY/.git/info/exclude"
    create_local_configuration

    create_worktree

    run diff -r "$EXPECTED" "$WORKTREE/.codex"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "worktree preserves target branch Codex files while adding local configuration" {
    create_local_configuration
    git -C "$REPOSITORY" add .codex
    git -C "$REPOSITORY" -c core.hooksPath=/dev/null commit --quiet --message "Add target configuration."
    git -C "$REPOSITORY" branch feature

    printf 'model = "local-test-model"\n' >"$REPOSITORY/.codex/config.toml"
    printf '#!/usr/bin/env bash\nexit 1\n' >"$REPOSITORY/.codex/hooks/test-hook.sh"
    printf 'description = "Local test agent"\n' >"$REPOSITORY/.codex/agents/test-agent.toml"
    printf 'description = "Additional test agent"\n' >"$REPOSITORY/.codex/agents/local-agent.toml"
    cp "$REPOSITORY/.codex/agents/local-agent.toml" "$EXPECTED/agents/"

    create_worktree

    run diff -r "$EXPECTED" "$WORKTREE/.codex"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    run git -C "$WORKTREE" diff --exit-code
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "worktree succeeds without Codex configuration" {
    create_worktree

    [ ! -e "$WORKTREE/.codex" ]
    run git -C "$WORKTREE" status --porcelain
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}
