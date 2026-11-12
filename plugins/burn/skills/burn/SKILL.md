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

Find the upstream-tracking commit the track worktrees will branch from (`git rev-parse @{upstream}`, falling back to the default branch). Each track run gets its own worktree from `<git-plugin-root>/scripts/worktree.sh` (the `git:worktree` skill), so a dirty checkout is fine and is never touched. Mention uncommitted changes in the summary, since they are not part of what the tracks see.

### Prove the baseline is green

Find the test command, in this order: git-test config (`git config --get-regexp '^test\.'`), `justfile` recipes, `package.json` scripts, a Makefile, then build files such as `pom.xml`, `pyproject.toml`, `Cargo.toml` or `go.mod`. Run it once on the upstream-tracking commit, in a scratch worktree.

- If it fails, stop and report the failing output. Burn has no build-fixing track.
- If no test command exists, only tracks that change no tests may run, and their branches are reported as "untested".

### Decide which tracks apply

Each track file under `references/tracks/` declares an `applies` key: `any`, or a detection key. Detect:

- `has-tests`: a test command was found and the repo contains test files.
- `has-coverage-tool`: c8 or `--coverage` support in Jest or Vitest, coverage.py or pytest-cov, Go's `-coverprofile`, `cargo tarpaulin`, or JaCoCo.
- `has-mutation-tool`: Stryker, PIT, mutmut or cargo-mutants.

A track applies when its key is detected, then `tracks` and `skipTracks` narrow the set. In Codex, the code-review track never applies, because `/code-review` is a Claude Code skill.

### Read the ledger

The ledger at `.llm/burn/ledger.json` records which paths each track covered and every queued finding's status. Update it from the task list first, so tasks the user deleted count as dismissed and checked tasks count as done:

```bash
python3 <plugin-root>/scripts/ledger.py sync-todo
```

Then, for each applicable track, list candidate shards in its declared granularity (`directory`, `file-set` or `whole-repo`, limited to `paths`) and pick the ones covered least recently:

```bash
python3 <plugin-root>/scripts/ledger.py pick --track <track> --count <n> <candidate>...
```

Spread the tier's track runs across applicable tracks, one shard per run. `ledger.py dismissed` prints the dismissed findings that track prompts must not raise again.

### Project the cost

Projected tokens come from the per-track spend in earlier runs' `.llm/burn/<date>/runs.json`. With no earlier run, say the projection is unknown rather than inventing a figure.

### Confirm the plan

Show the plan in one AskUserQuestion: each planned track run as track × shard, the branch cap, the verifier votes, the test command (or "untested") and the projected tokens. Offer to run it as planned, to run it at `small`, or to cancel. This is the last question of the run.

With `dryRun`, print the same plan and stop without asking. Nothing is created: no worktree, no branch, no ledger change other than the `sync-todo` update.

## Launch the workflow

The Workflow engine and the track files are not built yet. After the plan is confirmed, stop and tell the user that only preflight and `dryRun` exist so far.
