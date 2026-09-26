---
name: reword-commits
description: Rewrite every in-scope commit message (subject AND body) to a single line with git history reword. Use when the user asks to reword, rewrite, or clean up commit messages.
---

# Reword Commits

Use the `code:cli` and `git:git-workflow` skills. The message format in `git:git-workflow` is the target.

Rewrite every commit message in scope. Don't triage, and don't skip commits whose subjects already look fine: every commit gets a fresh proposal.

## Constraints

Use `git history reword` only: no interactive rebase, `git commit --amend`, `git filter-branch`, `git filter-repo`, or `git replay`. No branch switching, no force-pushing, and no changes to content, authors, dates, parents, or trees. Messages only.

## Scope

By default, reword the current branch's commits that aren't on its upstream: `<upstream>..HEAD`, falling back to `main..HEAD` or `master..HEAD`. If none apply, ask which base to use via AskUserQuestion.

If the user asks for "all branches", collect each local branch's commits not on its upstream (or the `main`/`master` fallback). A commit shared across branches is rewritten once, since `git history reword` updates every branch that contains it.

Anything else the user wrote is extra guidance on top of `git:git-workflow`. If the set is empty, say so and stop.

## Reading Each Commit

Read the full message, subject and body, for every commit. A body is itself a violation of the single-line rule.

```bash
git log --format='%H%n%B%n--END-COMMIT--' <range>
git show --no-patch --format=%B <sha>
```

If a message's intent is unclear, read the diff with `git show <sha>`.

## Drafting and Confirming

For each commit, draft one line that distills the full prior message (subject and body) and applies the user's extra guidance. Show before/after for every commit, noting any body being collapsed:

```text
<short-sha>  BEFORE: <current subject>  [+ N-line body]
             AFTER:  <proposed single-line message>
```

Then ask via AskUserQuestion:

- "Apply all rewrites" (recommended)
- "Apply a subset" (ask which SHAs)
- "Regenerate proposals"
- "Cancel"

## Applying

Run `git history reword <sha>` for each approved commit, oldest first, with a `GIT_EDITOR` that overwrites the whole message file so the body is dropped too:

```bash
MSG="<new single-line message>" GIT_EDITOR='sh -c "printf %s\\n \"$MSG\" > \"$1\"" --' git history reword <sha>
```

If any invocation fails, stop, report the SHA and error, and leave the rest alone. Don't fall back to `rebase -i` or `--amend`.

## Reporting

- Commits inspected and rewritten, with before/after.
- For "all branches": which branches now point at rewritten history.
- A note that pushed branches need a force-push to update the remote. Don't push.
