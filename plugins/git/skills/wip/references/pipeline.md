# /wip pipeline — patterns and edge cases

Non-obvious problems that show up on repos with many branches and worktrees. `origin/main` stands for your configured `$UPSTREAM_REMOTE/main` (see Phase 2 in SKILL.md).

## Worktree-per-branch parallel rebase (Phase 2)

`git-all` rebases serially in the main worktree and halts on the first conflict, leaving it detached and mid-rebase. For a large backlog, rebase each top branch in its own throwaway worktree, in parallel, so the main checkout is untouched and conflicts stay isolated.

For each branch that needs rebasing, spawn a `git:conflict-resolver` agent that:

- `git -C <main> worktree add <scratch>/wt-<sanitized-branch> <branch>` (sanitize `/` to `-`)
- `git -C <wt> -c core.editor=true rebase --rebase-merges --update-refs origin/main` with `GIT_EDITOR=true`
- On conflict: keep both the upstream's semantic changes and the branch's intended change, remove all markers, verify any `rerere` auto-staging, `git add`, `git rebase --continue`. Loop until `git -C <wt> status` no longer says "rebase in progress".
- Verifies `git merge-base --is-ancestor origin/main <branch>`.
- Tears down with `git -C <main> worktree remove --no-force <wt>`. If it's dirty, leave it and report.
- Doesn't push.

## Co-pointed or mutually contained branches

`rebase-all` skips any branch contained in another, expecting `--update-refs` to move it. This breaks when several branch names point at the same commit (e.g. `feature-a` and `feature-b`): `git branch --contains` reports each as contained in the other, so all of them are skipped and none move. They silently stay un-rebased.

Always run this fallback:

- After `git-all` reports done, recompute `git for-each-ref refs/heads/ --no-contains origin/main`.
- Rebase each remaining branch directly in its own worktree (the pattern above), ignoring containment. `rerere` makes these near-instant.
- Repeat until that set is empty.

An auto-continue loop that treats "nothing to commit" as "skip empty" can exit one step early when the final commit just needs a plain `git rebase --continue`. Drive the loop on the live `git status` "rebase in progress" signal, not the continue output.

## Test worktree setup (Phase 3)

git-test checks out each commit in the working tree, so give it a worktree to churn:

- `git -C <main> worktree add --detach <scratch>/wt-test origin/main`
- Copy the gitignored build-env files the build needs (commonly `.envrc`, `.mise/config.local.toml`, `CLAUDE.local.md`). Being gitignored, they won't trip a `_check-local-modifications` step.
- `mise trust <wt>` if the repo uses mise. The toolchain usually comes from global mise shims.
- With `<wt>` as the working directory, follow the `build:test-all` skill with `UPSTREAM_REMOTE=origin`, or run its `scripts/test-all default --verbose --verbose` directly. Drop the default `--retest` flag so git-test caches by tree and builds each unique tree once; rebased branches often share only a handful of unique trees.
- Launch long runs as a tracked background task so you get a completion notification, not `nohup … &`. Watch the first build to catch an env-wide failure early.
- Tear down with `git worktree remove --no-force`.

git-test caches results in `refs/notes/tests/<config>` keyed by tree, so reruns are cheap across worktrees.

## Flaky-retest rule (Phase 3)

A single transient failure is not a real failure. Integration tests that boot a server can fail with `java.net.SocketException: Connection reset` or similar. Before reporting a failure:

- Force-retest that commit: `git test run --force --tests <config> origin/main..<branch>`.
- If an interrupted test left the worktree dirty (e.g. a file-match test deleted an expected output), `git -C <wt> reset --hard` and re-detach on origin/main first. git-test refuses to run with unstaged changes.
- Only a reproducible failure goes to the `build:build-fixer-autosquash` fix loop.

## Moving targets

- Upstream main advances during a long run, sometimes with the WIP you committed in Phase 1. Re-`git fetch` and re-run `j g` if needed right before Phases 3 and 4.
- Worktrees appear and disappear, and the main checkout's branch may change. Recompute rather than assume, and ask before acting on a newly appeared worktree or branch.
