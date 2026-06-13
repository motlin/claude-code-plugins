---
name: git-reword-commits
description: Rewrite in-scope commit messages to single-line git-workflow messages with git history reword.
---

# Git Reword Commits

Use the `code:cli` and `git-workflow` skills.

Use `git history reword` only. Do not use interactive rebase, amend, filter-branch, filter-repo, or replay. Do not change commit content, authors, dates, parents, or trees.

Default scope is commits on the current branch not on upstream, or not on `main`/`master` when no upstream exists. If the user asks for all branches, collect every local branch's unique commits not on its upstream or fallback base.

Read full messages:

```bash
git log --format='%H%n%B%n--END-COMMIT--' <range>
```

Draft a replacement one-line message for every commit. Show before/after for every commit and ask for confirmation.

Apply approved rewrites oldest first:

```bash
MSG="<new single-line message>" GIT_EDITOR='sh -c "printf %s\\n \"$MSG\" > \"$1\"" --' git history reword <sha>
```

If any rewrite fails, stop and report the SHA and error. Do not push.
