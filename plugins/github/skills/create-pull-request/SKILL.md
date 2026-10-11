---
name: create-pull-request
description: Create a GitHub pull request the user's preferred way. Use whenever opening, creating, or raising a PR with gh.
---

# Create Pull Request

Use the `code:cli`, `git:git-workflow`, and `git:commit` skills when available. Only create a PR when the user has explicitly asked for one.

## Confirm the Branch Is on Upstream Main

```bash
git fetch "${UPSTREAM_REMOTE:-upstream}"
git merge-base --is-ancestor "${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}" HEAD
```

A non-zero exit means the branch is behind. Offer to rebase with the `git:git-rebase` skill rather than opening a stale PR.

## Title

Count the commits the branch adds with `git rev-list --count "${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}..HEAD"`.

- One commit: the title is that commit's message. Never type it from memory; read it from git in a subshell, `"$(git log -1 --pretty=%s)"`, so it matches exactly.
- More than one: write a one-line summary in commit message style.

## Create the PR

Always pass an explicit empty body so `gh` doesn't prompt or auto-fill. When a browser is available, use `--web` to open the prefilled page for final review. On a headless system, drop `--web`.

For a single-commit branch, read the title from git:

```bash
gh pr create --web --title "$(git log -1 --pretty=%s)" --body ""
```

For a multi-commit branch, pass the summary title you wrote:

```bash
gh pr create --web --title "Summary of the branch in commit message style" --body ""
```
