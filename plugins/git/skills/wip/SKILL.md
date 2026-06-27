---
name: wip
description: >-
    Run on /wip, or whenever the user wants a whole-repo git cleanup sweep across many worktrees and
    half-finished branches rather than an operation on one named branch or worktree. The trigger
    signal is breadth or chaining: tidying every leftover worktree AND every drifted branch together,
    or stringing several cleanup steps into one pass — remove stale worktrees, rebase all branches
    onto main, then re-test and push. Use it even for requests that look like plain git you could do
    by hand ("rebase all my branches and get them tested and pushed", "clean up branches and
    worktrees, rebase, test, push") — the skill exists to run them gated, never --force, and to
    handle the worktree/rebase/test edge cases. Typical asks: "clean up my worktrees and branches",
    "tidy up this repo before my next feature", "do the full wip cleanup pass", "remove the dead
    worktrees and rebase everything onto main", "settle my WIP". Defer to the single-operation git
    skills only when the user targets one specific branch or one specific worktree. Wraps
    git:clean-worktrees and build:test-all.
---

# /wip — work-in-progress cleanup pipeline

Drive a repo full of leftover worktrees and half-finished branches toward a clean, landed state.
The pipeline has four phases that run **in order**, each gated:

- **Worktrees** — remove every worktree except the main one and protected ones, freeing their
  branches for rebase.
- **Rebase + GC** — rebase every branch onto the upstream main (`j g` / `git-all`), deleting
  branches that have merged.
- **Test** — re-test the rebased commits (rebasing invalidates prior test results).
- **Push** — push the green branches; the user opens/merges PRs.

These four phases are the bulk-cleanup core of a longer idea → merged-PR lifecycle (the later
stages — open PR, CI, review, merge — are the user's call). If the repo or user documents a WIP
state model, follow it for those later stages.

## Golden rules (read before doing anything)

- **Never `--force`.** Worktree removal uses `git worktree remove --no-force` (write the flag
  explicitly); pushes use `git push --force-with-lease`. Git's refusal to act _is_ the safety
  net that protects uncommitted work and unexpected remote changes — don't defeat it.
- **The worktree/branch set is a moving target.** In an active repo, worktrees and branches get
  created, switched, and merged _while you work_ (often by other agents or the user). Recompute
  the live set with `git worktree list --porcelain` / `git for-each-ref` immediately before each
  action — never trust a snapshot from a minute ago. Re-`git fetch` before testing and pushing.
- **Gate the irreversible, outward-facing steps.** Removing a worktree with WIP, force-pushing,
  and `delete-merged` (which deletes remote branches) are hard to undo. Surface them and get the
  user's OK rather than charging ahead. Until the flow is proven smooth in a given repo, prefer
  asking at each phase boundary.
- **Work in dedicated worktrees, keep the main checkout clean.** Rebases and tests check out
  commits; doing that in the user's main worktree disrupts them and leaves it detached/mid-rebase.
  Isolate each in its own throwaway worktree (`git worktree add`), then tear it down.

## Configuration: which worktrees are protected

The **main worktree** is auto-detected — it is the first entry of `git worktree list --porcelain`
(equivalently, the one whose gitdir is `git rev-parse --git-common-dir`). Never remove it.

**Protected worktrees** (permanent ones to never remove) are listed per-repo in `.llm/wip.json`:

```json
{"protectedWorktrees": ["/Users/you/projects/some-permanent-worktree"]}
```

Read this file at the start of Phase 1. If it's missing, treat the protected set as empty (only
the main worktree is kept) — but if there's any long-lived worktree you're unsure about, ask
rather than remove it. (Alternative native mechanism: `git worktree lock` makes git refuse to
remove a worktree without `--force`, which our never-force rule respects automatically.)

## Phase 1 — Worktree cleanup

Goal: every non-main, non-protected worktree removed, so its branch is free to rebase.

- Read `.llm/wip.json` for `protectedWorktrees`. Detect the main worktree (first porcelain entry).
- Compute the removal set live: `git worktree list --porcelain` minus main minus protected. Use
  plain `git worktree list` — never a user shell alias like `git worktrees`, which won't exist
  elsewhere.
- Remove them **one at a time**, from the main repo, delegating to the `git:clean-worktrees`
  skill (which runs `git worktree remove --no-force <dir>` and lets git refuse unsafe removals):
  `git -C <main> worktree remove --no-force <dir>`.
- **Stop on the first failure — do not retry with `--force`.** A dirty worktree fails with
  `fatal: '<dir>' contains modified or untracked files, use --force to delete it` (exit 128).
  That's the safety net working. When it happens, look at what's there
  (`git -C <dir> status --short`) and ask the user how to handle it: **commit** the WIP (single
  line, via `git:commit-handler`), **stash** it, or **leave** the worktree in place.
- A brand-new clean+empty worktree (0 commits ahead of upstream, no changes) is probably someone
  about to start work — surface it, don't silently delete it.
- Finish with `git -C <main> worktree prune --verbose`.

## Phase 2 — Rebase every branch + GC

The one-shot is the **`git-all`** script — `rebase-all` → `git worktree prune` → `delete-merged`
(the user may alias it, e.g. `j g`). Prefer it over bare `rebase-all` so merged branches get
cleaned up. It needs the upstream configured (`UPSTREAM_REMOTE`, default `upstream`; many repos use
`origin` — check `git remote -v` and the project's `.envrc`). The `origin/main` written in the
examples below and in `references/pipeline.md` stands for whichever upstream you configured;
substitute `$UPSTREAM_REMOTE/main` when it isn't `origin`, or every rebase and "all clean" check
runs against a stale base and silently reports success.

- **Report the scope first.** "Rebase all" means every local branch not containing upstream/main,
  which can be _dozens_ (stale `dev`, `main4`, experiment, and `pr*-fix` branches). Count them and
  let the user confirm scope before a big batch.
- **Conflicts.** `git-all` halts on the first conflict, leaving an in-progress rebase. Hand genuine
  conflicts to the `git:conflict-resolver` agent. `git rerere` auto-replays the user's prior
  resolutions — verify them, don't blindly trust. (Beware false-positive conflict-marker greps in
  files that legitimately contain `=======`, e.g. ASCII banners or markdown headings.)
- **`delete-merged` is outward-facing** — it also `git push --delete origin <branch>` for merged
  remote branches (excluding main/HEAD/`origin/pr/*`). Gate it.

See `references/pipeline.md` for the **co-pointed-branch fallback** (the most important edge case:
when several branch names point at the same commit, `rebase-all` skips them all and they never
rebase — you must rebase the leftovers directly), and the recommended worktree-per-branch parallel
rebase pattern.

After this phase, `git for-each-ref refs/heads/ --no-contains origin/main` should be empty.

## Phase 3 — Test the rebased commits

Rebasing invalidates prior test results (the **rebase ⋈ test diamond**: a rebased branch must be
re-tested before it's trustworthy). Re-`git fetch` first — upstream may have moved.

Run `build:test-all` (per branch: `git test run <FLAGS> origin/main..BRANCH`) **in a
dedicated worktree** — git-test checks out each commit, which would disrupt the main checkout.
See `references/pipeline.md` for the worktree+env setup and the **flaky-retest** rule (force-retest
a single transient failure like `Connection reset` before reporting it as a real failure).

## Phase 4 — Push (push only; the user merges)

Record each branch's current remote sha (`git rev-parse refs/remotes/origin/<branch>`) **before**
re-`git fetch`ing, then push every branch ahead of upstream/main:

- If `refs/remotes/origin/<branch>` exists:
  `git push --force-with-lease=<branch>:<recorded-sha> origin <branch>:<branch>` (updates the open
  PR). Pin the sha explicitly — a bare `--force-with-lease` baselines on the remote-tracking ref,
  which the re-fetch just advanced to match the remote, so it would clobber a teammate's new commit
  instead of refusing. The pinned lease refuses if anyone pushed since you recorded the sha.
- Otherwise: `git push origin <branch>:<branch>` to create the remote branch.

Do **not** open or merge PRs unless asked — landing is the user's call. `git push` is commonly in
the harness "ask" list, so expect per-push permission prompts.

## What to ask vs. do autonomously

Mechanical and safe to automate: detecting main, reading the protected list, computing sets live,
`worktree remove --no-force`, `worktree prune`, clean rebases, tests, `--force-with-lease` pushes
of branches the user has scoped.

Judgment calls — ask: what to do with a **dirty** worktree; whether to remove a **brand-new** one;
**scope** of a big rebase/push batch; how to resolve a **genuine** conflict; and any **outward**
step (`delete-merged`, force-push, merge).
