---
argument-hint: [extra instructions, e.g. "all branches"]
description: Reword non-conforming commit messages with git history reword
---

Reword commit messages that don't match the format defined in the `git-workflow` skill.

ALWAYS use the `code:cli` and `git-workflow` skills. The rules in `git-workflow` are what to check against.

## Constraints

Use `git history reword` only. No interactive rebase, `git commit --amend`, `git filter-branch`, `git filter-repo`, or `git replay`. No branch switching, no force-pushing, no changes to commit content, authors, dates, parents, or trees. Messages only.

## Scope

The user passed in: `$ARGUMENTS`

Default scope is commits on the current branch that aren't on its upstream (or on `main`/`master` if there is no upstream). If the arguments ask for a wider scope like "all branches", expand to cover every local branch's unique commits. Anything else in the arguments is extra guidance to apply on top of the `git-workflow` rules.

## Picking the commit set

For the default scope, use `<upstream>..HEAD` if the branch has an upstream, otherwise `main..HEAD` or `master..HEAD`. If none of those apply, ask which base to use via AskUserQuestion.

For "all branches", collect commits reachable from each local branch but not from its upstream (or `main`/`master` fallback). A commit shared across branches gets rewritten once — `git history reword` updates every branch that contains it.

If the set is empty, say so and stop.

## Checking each commit

Re-read `git-workflow` and check each subject against its rules. Don't reimplement those rules here — they live in one place on purpose.

For each non-conforming commit, draft a replacement that:

- Preserves intent (read `git show <sha>` if the subject alone is ambiguous).
- Follows every rule from `git-workflow`.
- Incorporates the user's extra guidance, if any.

## Confirming

Show before/after for each proposed rewrite:

```
<short-sha>  BEFORE: <current subject>
             AFTER:  <proposed subject>
```

Mention the count of already-conforming commits without listing them. Then AskUserQuestion:

- "Apply all rewrites" (recommended)
- "Apply a subset" (ask which SHAs)
- "Regenerate proposals"
- "Cancel"

## Applying

Run `git history reword <sha>` for each approved commit, oldest first.

If any invocation fails, stop, report the SHA and error, and leave the rest alone. Don't fall back to `rebase -i` or `--amend`.

## Reporting

Wrap up with:

- Commits inspected, commits that already conformed, commits rewritten (with before/after).
- For "all branches": which branches now point at rewritten history.
- A note that pushed branches will need a force-push to update the remote. Don't push.
