# Burn report template

Write `REPORT.md` in this shape. Keep every section, writing "None." under a heading with nothing in it, so a reader can tell an empty run from a broken report.

```markdown
# Burn <date>

<One paragraph: how many track runs launched, how many branches survive, how many tasks were queued, and the tier.>

## Branches to review

<One section per kept branch, in rank order.>

### <rank>. <branch>

- **Track:** <track> over <shard>
- **Size:** <diffStat>
- **Tested:** yes, or "untested" when the repo has no test command
- **Why it ranks here:** <value against review effort, one or two sentences>
- **Evidence:** <the track's evidence, shortened but not paraphrased>
- **Review:** `git log -p <base>..<branch>`

## Queued tasks

<Each task the ledger accepted, as its title and the file it is about, under the `## burn <date>` heading it was added to in `.llm/todo.md`. Note how many findings were skipped because the ledger already knew them.>

## Runs not kept

| Run | Status | Reason | Branch |
| --- | ------ | ------ | ------ |
| <track>-<shard> | empty, refuted, gate-failed or failed | <reason> | <branch>, or "deleted" when `branchDeleted` is true |

<A failed, refuted or gate-failed branch with commits stays for the user to inspect; only a branch with no commits beyond the base is deleted. Then the runs that were never launched, and whether the tier's run count or the branch cap stopped them.>

## Unfinished worktrees

<Each `unfinishedWorktree` in the outcomes, with its run: git refused to remove it, usually because of uncommitted changes, and it was left as it is for the user. Write "None." when every worktree was removed.>

## Tracks to reconsider

<A track whose runs were refuted or failed the gate in this run and in earlier `.llm/burn/*/runs.json` files is a candidate for removal. Name it with its record, or write "None.">
```

Tokens spent per track are unknown, because concurrent runs share one budget counter; say so in the report. The run's total is not known until the Workflow returns, so the burn skill adds it to `runs.json` as `totalTokens` afterwards.
