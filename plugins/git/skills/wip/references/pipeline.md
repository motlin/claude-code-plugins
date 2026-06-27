# /wip pipeline — detailed patterns and edge cases

Read this when you hit Phase 2 (rebase) or Phase 3 (test). It captures the non-obvious things
that bite, learned from running this pipeline on a repo with ~50 branches and a dozen worktrees.
The `origin/main` in the examples stands for your configured `$UPSTREAM_REMOTE/main` (see Phase 2
in SKILL.md); substitute it when your upstream isn't `origin`.

## Worktree-per-branch parallel rebase (Phase 2)

`git-all` rebases serially in the main worktree and halts on the first conflict, leaving it
detached and mid-rebase. For a large backlog, it's cleaner to rebase each "top" branch in its own
throwaway worktree, in parallel, so the main checkout is never disturbed and conflicts are isolated:

For each branch that needs rebasing (see scope/containment below), spawn a `git:conflict-resolver`
agent that:

- `git -C <main> worktree add <scratch>/wt-<sanitized-branch> <branch>`
- `git -C <wt> -c core.editor=true rebase --rebase-merges --update-refs origin/main`
  (set `GIT_EDITOR=true` so nothing opens an editor)
- If it conflicts: resolve each file correctly (preserve the upstream's semantic changes AND the
  branch's intended change; remove all conflict markers; verify any `rerere` auto-staging is
  right, don't blind-trust it), `git add`, `git rebase --continue`; loop until
  `git -C <wt> status` no longer says "rebase in progress".
- Verify `git merge-base --is-ancestor origin/main <branch>`.
- Tear down: `git -C <main> worktree remove --no-force <wt>` (never `--force`; if it's dirty,
  leave it and report).

Sanitize `/` → `-` in branch names for the worktree dir. Don't push from these agents.

## EDGE CASE: co-pointed / mutually-contained branches (the big one)

`rebase-all` skips any branch "included in other branches" (an ancestor of another), expecting
`--update-refs` to move it when the containing branch rebases. This **breaks when several branch
names point at the same commit** — e.g. `codex/pr563-fix` and `land/database-prune-backups` on the
identical commit. `git branch --contains` then reports each as contained in the other (mutual
containment), so `rebase-all` skips **all** of them and `--update-refs` never moves them. They
silently stay un-rebased.

Fallback (always run it):

- After `git-all` reports done, recompute `git for-each-ref refs/heads/ --no-contains origin/main`.
- For whatever remains, **rebase each one directly in its own worktree** (the per-branch pattern
  above), ignoring containment. `rerere` makes these near-instant since the resolutions already
  exist from this session.
- Repeat until the `--no-contains origin/main` set is empty.

Minor gotcha: an auto-continue loop that treats "nothing to commit" as "skip empty" can exit one
step early when the _final_ commit just needs a plain `git rebase --continue`. Drive the loop on
the live `git status` "rebase in progress" signal, not on the continue's output text.

## Dedicated test worktree setup (Phase 3)

git-test runs the configured test on each commit by checking it out in the working tree, so it
needs a worktree it can churn:

- `git -C <main> worktree add --detach <scratch>/wt-test origin/main`
- Copy the gitignored build-env files the build needs (varies by repo; commonly `.envrc`,
  `.mise/config.local.toml`, a `CLAUDE.local.md`). These are gitignored, so they don't make the
  tree "dirty" and won't trip a `_check-local-modifications` test step.
- `mise trust <wt>` (if the repo uses mise). The toolchain usually comes from global mise shims,
  so any directory can build.
- Run the tests there: `cd <wt> && UPSTREAM_REMOTE=origin build:test-all` (or the script
  directly). Drop the default `--retest` flag so git-test caches by tree and builds each unique
  tree once — important when many branches share rebased commits (often only a handful of unique
  trees across dozens of branches).
- Prefer launching long runs as a **tracked** background task (so you get a completion
  notification) rather than `nohup … &` (which detaches from the harness and forces you to poll a
  log file). Either way, watch the first build to catch an env-wide failure early.
- Tear the worktree down with `git worktree remove --no-force` when done.

git-test caches results in `refs/notes/tests/<config>` keyed by tree, so reruns are cheap and the
cache survives across worktrees.

## Flaky-retest rule (Phase 3)

A single transient failure is not a real failure. Integration tests that boot a server and make
HTTP calls can fail with `java.net.SocketException: Connection reset` or similar socket errors —
flaky, not a logic break. Before reporting any failure as real:

- Force-retest just that commit: `git test run --force --tests <config> origin/main..<branch>`.
- If a killed/interrupted test left the worktree dirty (e.g. a file-match test deleted an expected
  output and never regenerated it), `git -C <wt> reset --hard` and re-detach on origin/main before
  retesting — git-test refuses to run with unstaged changes.
- If the retest passes, it was flaky. Only a _reproducible_ failure is a real failure worth the
  `build:build-fixer-autosquash` fix loop.

## Moving-target discipline

Across a long run, the upstream and the branch set drift:

- Upstream main advances (other work merges — sometimes the very WIP you committed in Phase 1).
  Re-`git fetch` and, if needed, re-run `j g` right before Phase 3 and Phase 4 so you're rebased
  onto current main. Accept that you may need another pass.
- Worktrees appear/disappear and the main checkout's branch may change under you. Recompute, don't
  assume. When in doubt about a newly-appeared worktree or branch, ask before acting on it.
