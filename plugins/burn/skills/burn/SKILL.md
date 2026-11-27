---
name: burn
description: 'Spend spare weekly quota before the usage reset: fan out improvement skills (code review, test speed, coverage, mutation testing, assertions) in separate worktrees, and leave tested local branches, plus a built branch with a recommendation for each design question, for review. Never pushes or opens PRs. Use when the user runs /burn or asks to burn, use up, or spend remaining quota on real improvements.'
---

# Burn

Turn quota that would otherwise expire into reviewable work on existing code. The run leaves local `burn/<date>/<track>-<shard>` branches that pass tests, plus `burn/<date>/idea-<title>` branches that each build one design question a track raised and say whether to keep it. Nothing is queued in `.llm/todo.md`. The run never asks the user anything: a track fixes what needs no decision, drops what the repository cannot fix, and hands only design questions to the idea phase. It never pushes and never opens PRs. An empty run is a valid outcome: a track that finds nothing worth doing produces no branch.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/burn/SKILL.md` file.

Invoking `/burn` is the user's opt-in to a large Workflow, and the user usually walks away right after starting it. Ask the user nothing at any point: preflight, the plan and the launch all happen in the turn that invoked `/burn`, and a question would leave the run sitting idle for hours. All run output goes under `.llm/burn/`; check that `.llm/` is gitignored before writing there.

## Arguments

| Arg          | Default        | Meaning                                                                          |
| ------------ | -------------- | -------------------------------------------------------------------------------- |
| `size`       | `medium`       | `small`, `medium` or `max`; sets the track runs, effort level and verifier votes |
| `tracks`     | all that apply | Restrict to the named tracks                                                     |
| `skipTracks` | none           | Exclude the named tracks                                                         |
| `paths`      | whole repo     | Restrict to these directories; use it for a first trial run on one directory     |
| `dryRun`     | false          | Run preflight, print the planned track runs and projected tokens, then stop      |

| Tier     | Track runs | Effort   | Verifier votes |
| -------- | ---------- | -------- | -------------- |
| `small`  | 3          | `medium` | 1              |
| `medium` | 6          | `high`   | 2              |
| `max`    | 12         | `max`    | 3              |

Claude Code exposes no API for remaining weekly quota, so `size` is the only spending control. Its effort level goes to every track and idea agent, and fills `{level}` in a track's `invokes`, the way `/code-review` takes a level. Nothing caps the branches a run leaves: every planned run launches, and every design question a track raises is built.

## Preflight

Do preflight yourself, in this session, before any Workflow launches. Run these checks in order and stop at the first failure, reporting why instead of asking how to proceed.

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
- `has-prompts`: the repo has skills (`SKILL.md`), agents, commands, hooks, or a `CLAUDE.md` or `AGENTS.md`.
- `has-memories`: the repository's auto-memory folder, `~/.claude/projects/<slug>/memory/` with `<slug>` the repository path with every character other than a letter or digit replaced by `-`, holds memory files.
- `has-docs`: the repository has prose docs for readers beyond a bare README, such as a `docs/` directory or several Markdown guides.
- `has-dependencies`: the repository declares dependencies in its own manifest, such as `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, a Gradle build or `mise.toml`.
- `has-type-checker`: the repository is type-checked, by `tsconfig.json`, mypy or pyright config, or a statically typed language such as Java, Kotlin, Go or Rust.
- `has-template`: a sibling repository with a `.claude/commands/sync-template.md` lists this repository in its `.llm/projects.yaml`, by `own`, `forks` or `nested`, or by `scan` without a `skip`; or this repository is itself such a template.

A track applies when its key is detected, then `tracks` and `skipTracks` narrow the set. In Codex, the code-review and memory tracks never apply, because `/code-review` and auto-memory are Claude Code features. The duplication track also needs the `goal-sloc` skill, which this marketplace does not ship: skip it when `goal-sloc` is not among the available skills.

### Read the ledger

The ledger at `.llm/burn/ledger.json` records which paths each track covered and the status of findings earlier runs queued. Update it from the task list first, so tasks the user deleted count as dismissed and checked tasks count as done:

```bash
python3 <plugin-root>/scripts/ledger.py sync-todo
```

Then, for each applicable track, list candidate shards in its declared granularity (`directory`, `file-set`, `whole-repo` or `skill`, limited to `paths`) and pick the ones covered least recently.

A `skill` shard is the name of an installed skill that is relevant to this repository and no other track already runs. Go through the skills available in this session and keep those whose subject the repository actually uses, judging by its files rather than the skill's name alone: for example `temporal-data:temporal-data` for bitemporal or audit tables, `java:openrewrite` and `java:pom-ordering` for Maven projects, and `justfile:justfile-style` for a `justfile`. Leave out skills about workflows rather than code, such as git, task lists, reviews of the user's day, mail, and burn itself; skills the other tracks already invoke; and `security-review`, which burn does not run.

```bash
python3 <plugin-root>/scripts/ledger.py pick --track <track> --count <n> <candidate>...
```

Spread the tier's track runs across applicable tracks, one shard per run. When the tier allows fewer runs than there are applicable tracks, give the runs to tracks the ledger has never recorded first, then to those whose latest coverage date is oldest, so successive burn runs rotate through every track. `ledger.py dismissed` prints the dismissed findings that track prompts must not raise again.

### Project the cost

Concurrent track runs share one budget counter, so there is no per-track spend. Project from the `totalTokens` that earlier runs recorded in `.llm/burn/<date>/runs.json`: divide each by its count of launched runs, and multiply the average by the planned run count. With no earlier total, say the projection is unknown rather than inventing a figure.

### Show the plan

Print the plan as text, then launch it without waiting for a reply. The plan lists each planned track run as track × shard, the effort level, the verifier votes, the test command (or "untested") and the projected tokens. List applicable tracks left out as not in this run, and say the next burn run picks them first; burn schedules nothing, so name no time and never imply it will come back on its own. Users who want to review a plan before spending on it run with `dryRun`.

With `dryRun`, print the same plan and stop. Nothing is created: no worktree, no branch, no ledger change other than the `sync-todo` update.

## Launch the workflow

The engine is a Workflow script, `<plugin-root>/scripts/burn-workflow.js`. It runs five phases:

- **Run tracks:** one agent per track run, each in its own worktree `<repo>-burn-<date>-<track>-<shard>` on the branch `burn/<date>/<track>-<shard>`. The repository name keeps two repos burned on the same day from colliding in the shared parent directory. Every planned run launches at once.
- **Build ideas:** after the tracks, one agent per design question builds it completely in its own worktree on `burn/<date>/idea-<title>`, then recommends keeping or dropping it from what building it showed. Every idea is built; none is queued. An idea its builder recommends dropping keeps its branch and skips verify and gate.
- **Verify:** fresh-context verifiers try to refute each branch. On an idea branch they check that the implementation is complete and the evidence supports the recommendation, not whether they would have made the same choice. A branch needs more than half the votes to survive; a verifier that dies counts as refuting.
- **Gate:** the test command, or `git test run <base>..<branch>` when git-test is configured, runs once on each surviving branch, in the background so a suite longer than the foreground command limit still finishes before the gate reports. With no test command, kept branches are marked untested.
- **Rank and report:** one agent ranks the kept branches, reports idea branches as questions with their recommendations, records coverage with `ledger.py record`, and writes `runs.json` and `REPORT.md` from `references/report-template.md`. Worktrees are removed; branches stay.

A failed, empty, refuted or gate-failed run is never re-run. Cleanup never forces anything: worktrees are removed with a plain `git worktree remove`, and one that git refuses to remove, usually for uncommitted changes, stays and is reported as unfinished. A run's branch stays for the user to inspect, and is listed in `REPORT.md` with its status, unless it has no commits beyond the base, in which case `git branch -d` deletes it.

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
| `tier`           | `{runs, votes, effort}` from the tier table                                                 |
| `runs`           | the planned runs: `[{track, shard, invokes, evidence, instructions}]` in launch order       |
| `dismissed`      | the `track`, `path` and `symbol` of each entry `ledger.py dismissed` printed                |

Launch the run in the same turn as preflight, right after printing the plan. Workflow subagents read the user's latest message as the request they serve, and that message is the `/burn` invocation.

To resume a stopped run, re-invoke Workflow with the persisted script path and `resumeFromRunId`, with the args unchanged, so finished track runs replay from cache.

When it returns, add the run's total token spend from the Workflow result to `runs.json` as `totalTokens`, so the next preflight can project its cost. Then show the user the ranked branches, each idea branch with its keep or drop recommendation, and the Workflow result's `report` path. When `report` is null the report agent did not write `REPORT.md`; say so. Never push or open a PR.

## Run it in Codex

Codex has no Workflow tool, so you are the orchestrator and do by hand what the script does, serially, at the `small` tier whatever `size` says: 3 track runs, `medium` effort, and 1 verifier vote. The code-review track never applies in Codex. The script stays the single source of truth for the briefs: read `<plugin-root>/scripts/burn-workflow.js` and reuse its track, verify, gate, cleanup and rank-and-report prompts verbatim, filling each `${...}` from the same args you would have passed.

- Take one planned track run at a time, in plan order. If Codex can start subagents, give the track run its own subagent so its work stays out of your context. Otherwise do it in your own context, keeping only its summary, evidence, diff stat and findings.
- A track run that fails or commits nothing gets the cleanup prompt and is recorded as `failed` or `empty`.
- Verify a committed branch with the verify prompt in a fresh subagent. Without subagents, verify it yourself from the diff and the evidence alone, and note in the report that its verifier was not fresh-context. A refuted branch gets the cleanup prompt and is recorded as `refuted`.
- Gate a surviving branch by running the gate prompt's command once in its worktree. A failing branch gets the cleanup prompt and is recorded as `gate-failed`. With no test command, keep it as untested.
- Never re-run a failed, empty, refuted or gate-failed run, and never fix a branch to make it pass.
- After each run, append its outcome to `.llm/burn/<date>/runs.json` in the shape the script builds. Long runs outlive one Codex session, and `runs.json` is the resume point: a fresh session continues from the first planned run it does not list.
- When every run is done, deduplicate the findings by track, path and symbol, dropping dismissed ones. Build each one with the idea prompt, verify a keep recommendation with the idea verify prompt and gate it, then follow the rank-and-report prompt and remove the kept branches' worktrees with the cleanup prompt. Report as the Workflow would, and never push or open a PR.
