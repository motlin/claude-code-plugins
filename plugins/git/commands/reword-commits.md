---
argument-hint: [extra instructions, e.g. "all branches"]
description: Rewrite every in-scope commit message (subject AND body) to a single line with git history reword
---

Rewrite **every** commit message in scope to a single line that follows the `git-workflow` skill. Do not triage. Do not skip commits whose subjects already look fine — if the user invoked this command, every commit needs a fresh message.

ALWAYS use the `code:cli` and `git-workflow` skills. The rules in `git-workflow` are what to write toward.

## Constraints

Use `git history reword` only. No interactive rebase, `git commit --amend`, `git filter-branch`, `git filter-repo`, or `git replay`. No branch switching, no force-pushing, no changes to commit content, authors, dates, parents, or trees. Messages only.

## Scope

The user passed in: `$ARGUMENTS`

Default scope is commits on the current branch that aren't on its upstream (or on `main`/`master` if there is no upstream). If the arguments ask for a wider scope like "all branches", expand to cover every local branch's unique commits. Anything else in the arguments is extra guidance to apply on top of the `git-workflow` rules.

## Picking the commit set

For the default scope, use `<upstream>..HEAD` if the branch has an upstream, otherwise `main..HEAD` or `master..HEAD`. If none of those apply, ask which base to use via AskUserQuestion.

For "all branches", collect commits reachable from each local branch but not from its upstream (or `main`/`master` fallback). A commit shared across branches gets rewritten once — `git history reword` updates every branch that contains it.

If the set is empty, say so and stop.

## Reading each commit

Read the **full message** — subject and body — for every commit. A body is itself a violation of the single-line rule, so you have to see it to fix it.

Stream every full message in scope with this command:

```sh
git log --format='%H%n%B%n--END-COMMIT--' <range>
```

For one commit at a time:

```sh
git show --no-patch --format=%B <sha>
```

If a message's intent isn't clear from the text, run `git show <sha>` to see the diff.

## Drafting

For **every** commit in scope, draft a replacement single-line message that:

- Follows every rule from `git-workflow` (one line, present-tense verb, length range, trailing period, no praise adjectives).
- Distills the full prior message (subject + body) into one line — never copy the body verbatim, never preserve paragraphs.
- Incorporates the user's extra guidance, if any.

Do not categorize commits as "already conforming." Every commit gets a proposed rewrite.

## Confirming

Show before/after for every commit. When the prior message has a body, indicate that in the BEFORE so the user can see what's being collapsed:

```
<short-sha>  BEFORE: <current subject>  [+ N-line body]
             AFTER:  <proposed single-line message>
```

Then AskUserQuestion:

- "Apply all rewrites" (recommended)
- "Apply a subset" (ask which SHAs)
- "Regenerate proposals"
- "Cancel"

## Applying

Run `git history reword <sha>` for each approved commit, oldest first, with a `GIT_EDITOR` that overwrites the message file so the body is dropped (not just the subject):

```sh
MSG="<new single-line message>" GIT_EDITOR='sh -c "printf %s\\n \"$MSG\" > \"$1\"" --' git history reword <sha>
```

If any invocation fails, stop, report the SHA and error, and leave the rest alone. Don't fall back to `rebase -i` or `--amend`.

## Reporting

Wrap up with:

- Commits inspected, commits rewritten (with before/after).
- For "all branches": which branches now point at rewritten history.
- A note that pushed branches will need a force-push to update the remote. Don't push.
