# Burn report template

Write `REPORT.md` in this shape. Keep every section, writing "None." under a heading with nothing in it, so a reader can tell an empty run from a broken report.

```markdown
# Burn <date>

<One paragraph: how many track runs launched, how many ideas were built, how many branches survive, and the tier.>

## Branches to review

<One section per kept track branch, in rank order. Idea branches go under Ideas to decide.>

### <rank>. <branch>

- **Track:** <track> over <shard>
- **Size:** <diffStat>
- **Tested:** yes, or "untested" when the repo has no test command
- **Why it ranks here:** <value against review effort, one or two sentences>
- **Evidence:** <the track's evidence, shortened but not paraphrased>
- **Review:** `git log -p <base>..<branch>`

## Ideas to decide

<One section per kept idea branch: a design question a track raised, built so the user can decide by looking at a working change.>

### <branch>

- **Question:** <the idea's question>
- **Raised by:** <track> over <path>
- **Built:** <summary>; <diffStat>
- **Recommendation:** keep or drop, and the builder's rationale
- **Alternative:** <the answer it did not build>
- **Tested:** yes, or "untested"
- **Review:** `git log -p <base>..<branch>`

## Ideas tried and dropped

<One line per idea its builder recommended dropping: the branch, the question and the rationale. The branch stays in case the user wants to look.>

## Changes outside git

<Every change a track made outside the repository, such as memory files deleted, shrunk or corrected, with the backup path it left. Then each kept branch's `afterKept` steps, saying whether they were done; a step not done still needs doing by hand. Write "None." when nothing changed outside git.>

## Runs not kept

| Run | Status | Reason | Branch |
| --- | ------ | ------ | ------ |
| <track>-<shard> or idea-<title> | empty, refuted, gate-failed or failed | <reason> | <branch>, or "deleted" when `branchDeleted` is true |

<A failed, refuted or gate-failed branch with commits stays for the user to inspect; only a branch with no commits beyond the base is deleted. Then the runs the tier's run count left out.>

## Unfinished worktrees

<Each `unfinishedWorktree` in the outcomes, with its run: git refused to remove it, usually because of uncommitted changes, and it was left as it is for the user. Write "None." when every worktree was removed.>

## Tracks to reconsider

<A track whose runs were refuted or failed the gate in this run and in earlier `.llm/burn/*/runs.json` files is a candidate for removal. Name it with its record, or write "None.">
```

Tokens spent per track are unknown, because concurrent runs share one budget counter; say so in the report. The run's total is not known until the Workflow returns, so the burn skill adds it to `runs.json` as `totalTokens` afterwards.
