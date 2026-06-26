---
name: create-pull-request
description: Create a GitHub pull request the user's preferred way. Use whenever opening, creating, or raising a PR with gh.
---

# Create Pull Request

Use the `code:cli`, `git-workflow`, and `git-commit` skills when available. Only create a PR when the user has explicitly asked for one.

## Confirm the branch is on top of upstream main

Fetch first, then test whether the branch already contains the tip of `origin/main`:

```bash
git fetch origin
git merge-base --is-ancestor origin/main HEAD
```

- Non-zero means the branch is behind. Offer to rebase onto `origin/main` before creating the PR rather than opening a stale PR.

## Set the title from the actual commit message

Never type the title from memory. Read it from git in a subshell so it matches exactly.

First count the commits the branch adds over `origin/main`:

```bash
git rev-list --count origin/main..HEAD
```

- if one commit, then the title is that commit's message.

    ```bash
    git log -1 --pretty=%s
    ```

- More than one: write a short one-sentence summary title — same style as a commit message (present-tense verb, one line, no trailing paragraphs).

## Keep the body empty

Always pass an explicit empty string for the body so `gh` does not prompt or auto-fill.

```bash
--body ""
```

## Create the PR

When a browser is available, open the prefilled page for final review:

```bash
gh pr create --web --title "$(git log -1 --pretty=%s)" --body ""
```

On a headless system without a browser, drop `--web`:

```bash
gh pr create --title "$(git log -1 --pretty=%s)" --body ""
```
