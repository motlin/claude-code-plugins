---
name: burn
description: 'Spend spare weekly quota the night before the usage reset: fan out improvement skills (code review, test speed, coverage, mutation testing, assertions) in separate worktrees, and leave a few tested local branches plus a ranked task queue for the morning. Never pushes or opens PRs. Use when the user runs /burn or asks to burn, use up, or spend remaining quota on real improvements.'
---

# Burn

Turn quota that would otherwise expire into reviewable work on existing code. The run leaves local `burn/<date>/<track>-<shard>` branches that pass tests, and appends queued findings to `.llm/todo.md`. It never pushes and never opens PRs. An empty night is a valid outcome: a track that finds nothing worth doing produces no branch.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/burn/SKILL.md` file.

Invoking `/burn` is the user's opt-in to a large Workflow. All run output goes under `.llm/burn/`; confirm `.llm/` is gitignored before writing there.

## Arguments

| Arg           | Default        | Meaning                                                                        |
| ------------- | -------------- | ------------------------------------------------------------------------------ |
| `size`        | `medium`       | `small`, `medium` or `max`; sets the track runs, branch cap and verifier votes |
| `tracks`      | all that apply | Restrict to the named tracks                                                   |
| `skipTracks`  | none           | Exclude the named tracks                                                       |
| `maxBranches` | from `size`    | Hard cap on branches left for review                                           |
| `paths`       | whole repo     | Restrict to these directories; use it for a first trial run on one directory   |
| `dryRun`      | false          | Run preflight, print the planned track runs and projected tokens, then stop    |

| Tier     | Track runs | Branch cap | Verifier votes |
| -------- | ---------- | ---------- | -------------- |
| `small`  | 3          | 3          | 1              |
| `medium` | 6          | 5          | 2              |
| `max`    | 12         | 8          | 3              |

Claude Code exposes no API for remaining weekly quota, so `size` is the only spending control. The branch cap is a hard limit, because the user's morning review is the scarce resource.

## Preflight

Do preflight yourself, in this session, before any Workflow launches: it may need the user's answers, and after the plan confirmation the run is unattended. Run these checks in order and stop at the first failure.

### Check the starting point

Find the upstream-tracking commit the track worktrees will branch from (`git rev-parse @{upstream}`, falling back to the default branch). Each track run gets its own worktree beside the repository, the way the `git:worktree` skill places them, but created with `git worktree add` from this exact commit, because `worktree.sh` only branches from a remote branch. A dirty checkout is fine and is never touched. Mention uncommitted changes in the summary, since they are not part of what the tracks see.

### Prove the baseline is green

Find the test command, in this order: git-test config (`git config --get-regexp '^test\.'`), `justfile` recipes, `package.json` scripts, a Makefile, then build files such as `pom.xml`, `pyproject.toml`, `Cargo.toml` or `go.mod`. Run it once on the upstream-tracking commit, in a scratch worktree.

- If it fails, stop and report the failing output. Burn has no build-fixing track.
- If no test command exists, only tracks that change no tests may run, and their branches are reported as "untested".

### Decide which tracks apply

Each track file under `references/tracks/` declares an `applies` key: `any`, or a detection key. Detect:

- `has-tests`: a test command was found and the repo contains test files.
- `has-coverage-tool`: c8 or `--coverage` support in Jest or Vitest, coverage.py or pytest-cov, Go's `-coverprofile`, `cargo tarpaulin`, or JaCoCo.
- `has-mutation-tool`: Stryker, PIT, mutmut or cargo-mutants.

A track applies when its key is detected, then `tracks` and `skipTracks` narrow the set. In Codex, the code-review track never applies, because `/code-review` is a Claude Code skill. The duplication track also needs the `goal-sloc` skill, which this marketplace does not ship: skip it when `goal-sloc` is not among the available skills.

### Read the ledger

The ledger at `.llm/burn/ledger.json` records which paths each track covered and every queued finding's status. Update it from the task list first, so tasks the user deleted count as dismissed and checked tasks count as done:

```bash
python3 <plugin-root>/scripts/ledger.py sync-todo
```

Then, for each applicable track, list candidate shards in its declared granularity (`directory`, `file-set` or `whole-repo`, limited to `paths`) and pick the ones covered least recently:

```bash
python3 <plugin-root>/scripts/ledger.py pick --track <track> --count <n> <candidate>...
```

Spread the tier's track runs across applicable tracks, one shard per run. When the tier allows fewer runs than there are applicable tracks, give the runs to tracks the ledger has never recorded first, then to those whose latest coverage date is oldest, so successive nights rotate through every track. `ledger.py dismissed` prints the dismissed findings that track prompts must not raise again.

### Project the cost

Concurrent track runs share one budget counter, so there is no per-track spend. Project from the `totalTokens` that earlier runs recorded in `.llm/burn/<date>/runs.json`: divide each by its count of launched runs, and multiply the average by the planned run count. With no earlier total, say the projection is unknown rather than inventing a figure.

### Confirm the plan

Show the plan in one AskUserQuestion: each planned track run as track × shard, the branch cap, the verifier votes, the test command (or "untested") and the projected tokens. Offer to run it as planned, to run it at `small`, or to cancel. This is the last question of the run.

With `dryRun`, print the same plan and stop without asking. Nothing is created: no worktree, no branch, no ledger change other than the `sync-todo` update.

## Launch the workflow

The engine is a Workflow script, `<plugin-root>/scripts/burn-workflow.js`. It runs four phases:

- **Run tracks:** one agent per track run, each in its own worktree on the branch `burn/<date>/<track>-<shard>`. Launches stop while kept branches plus runs in flight reach the branch cap; a run that ends without a branch frees its slot.
- **Verify:** fresh-context verifiers try to refute each branch. A branch needs more than half the votes to survive; a verifier that dies counts as refuting.
- **Gate:** the test command, or `git test run <base>..<branch>` when git-test is configured, runs once on each surviving branch. With no test command, kept branches are marked untested.
- **Rank and report:** one agent ranks the kept branches, queues new findings in `.llm/todo.md` through `ledger.py merge`, records coverage with `ledger.py record`, and writes `runs.json` and `REPORT.md` from `references/report-template.md`. Worktrees are removed; branches stay.

A failed, empty, refuted or gate-failed run has its worktree and branch deleted, and is never re-run.

Read each planned run's track file from `references/tracks/<track>.md`: its frontmatter gives `invokes` and `evidence`, and its body is the run's `instructions`. Then call Workflow with `scriptPath: <plugin-root>/scripts/burn-workflow.js` and these `args`:

| Arg              | Value                                                                                       |
| ---------------- | ------------------------------------------------------------------------------------------- |
| `repo`           | absolute path of the repository                                                             |
| `base`           | the upstream-tracking commit from preflight                                                 |
| `date`           | today, `YYYY-MM-DD`                                                                         |
| `runDir`         | absolute path of `.llm/burn/<date>`                                                         |
| `worktreeRoot`   | the repository's parent directory, so worktrees sit beside it as `git:worktree` places them |
| `ledger`         | absolute path of `<plugin-root>/scripts/ledger.py`                                          |
| `reportTemplate` | absolute path of `<plugin-root>/skills/burn/references/report-template.md`                  |
| `testCommand`    | the test command from preflight, or `null`                                                  |
| `gitTest`        | `true` when `git config --get-regexp '^test\.'` found a git-test command                    |
| `tier`           | `{runs, maxBranches, votes}` from the tier table, with `maxBranches` overriding the cap     |
| `runs`           | the confirmed plan: `[{track, shard, invokes, evidence, instructions}]` in launch order     |
| `dismissed`      | the `track`, `path` and `symbol` of each entry `ledger.py dismissed` printed                |

Launch the run only in the turn where the user confirmed the plan. Workflow subagents read the user's latest message as the request they serve.

To resume a stopped run, re-invoke Workflow with the persisted script path and `resumeFromRunId`, with the args unchanged, so finished track runs replay from cache.

When it returns, add the run's total token spend from the Workflow result to `runs.json` as `totalTokens`, so the next preflight can project its cost. Then show the user the ranked branches, the number of queued tasks and the path of `REPORT.md`. Never push or open a PR.

## Run it in Codex

Codex has no Workflow tool, so you are the orchestrator and do by hand what the script does, serially, at the `small` tier whatever `size` says: 3 track runs, a branch cap of 3 (lower when `maxBranches` says so), and 1 verifier vote. The code-review track never applies in Codex. The script stays the single source of truth for the briefs: read `<plugin-root>/scripts/burn-workflow.js` and reuse its track, verify, gate, cleanup and rank-and-report prompts verbatim, filling each `${...}` from the same args you would have passed.

- Take one planned track run at a time, in plan order. If Codex can start subagents, give the track run its own subagent so its work stays out of your context. Otherwise do it in your own context, keeping only its summary, evidence, diff stat and findings.
- A track run that fails or commits nothing gets the cleanup prompt's branch deletion and is recorded as `failed` or `empty`.
- Verify a committed branch with the verify prompt in a fresh subagent. Without subagents, verify it yourself from the diff and the evidence alone, and note in the report that its verifier was not fresh-context. A refuted branch is deleted and recorded as `refuted`.
- Gate a surviving branch by running the gate prompt's command once in its worktree. A failing branch is deleted and recorded as `gate-failed`. With no test command, keep it as untested.
- Stop launching once the kept branches reach the branch cap. A run that ends without a branch frees its slot.
- Never re-run a failed, empty, refuted or gate-failed run, and never fix a branch to make it pass.
- After each run, append its outcome to `.llm/burn/<date>/runs.json` in the shape the script builds. Long runs outlive one Codex session, and `runs.json` is the resume point: a fresh session continues from the first planned run it does not list.
- When every run is done, deduplicate the findings by track, path and symbol, dropping dismissed ones, then follow the rank-and-report prompt, and remove the kept branches' worktrees with the cleanup prompt. Report as the Workflow would, and never push or open a PR.
