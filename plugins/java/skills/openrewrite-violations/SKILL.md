---
name: openrewrite-violations
description: Apply every configured OpenRewrite recipe with violations on a dedicated branch, creating one commit per named leaf recipe and verifying the cumulative result. Use when asked to fix all OpenRewrite violations, create an OpenRewrite cleanup branch, or commit recipe changes separately.
---

# Fix OpenRewrite Violations

Create a branch named `openrewrite-violations` (or the name the user supplies), then apply every configured OpenRewrite recipe that has violations one at a time, one commit per recipe, with the message `Fix violations of OpenRewrite rule: <recipe>.`

Follow the `java:maven-cli` skill for Maven, and the `git:git-workflow` skill for commits; delegate each commit to the `git:commit-handler` agent.

## Start from a clean checkout

Run `git status --porcelain`. If there are uncommitted changes, stop and tell the user: this workflow creates commits and must start clean. Do not stash, discard, or absorb their work.

Branch from the fetched upstream default branch:

```bash
git fetch origin
git switch -c openrewrite-violations origin/HEAD
```

Use `git worktree add` instead if the user is mid-work on another branch and their checkout should not move.

## Find the recipes with violations

Follow the discovery, dry-run, and leaf-recipe sections of the `java:openrewrite-analyze-recipes` skill: the mise and justfile conventions, the `rewrite-dry-run` / `rewrite <RECIPE>` recipes, the profile flag, and the `-Drewrite.pomCacheEnabled=false` workaround all apply here. Treat each distinct named leaf recipe as one rule.

Present the ordered list to the user before applying changes.

## Apply and commit each recipe

In a stable order, run each recipe in isolation against the tree left by the previous commits:

```bash
mise exec -- just rewrite <recipe>
# or: mise exec -- mvn rewrite:run -Drewrite.activeRecipes=<recipe> -Drewrite.pomCacheEnabled=false
```

- Skip a recipe that produces no changes; an earlier one may have covered it. Never create an empty commit.
- Stage only the files that recipe changed.
- Run the repository's required checks for the change.
- Commit with `Fix violations of OpenRewrite rule: <fully-qualified-recipe>.` through `git:commit-handler`.

## Verify the cumulative branch

After all commits, build and test the whole project (`mise exec -- just test`, or `mvn verify`). A recipe that applies cleanly in isolation can still break the cumulative tree, so this check is mandatory.

If a recipe produced non-compiling or failing code, find its commit with `git log --oneline`, then fold a fix into that commit (without combining unrelated rules) or drop it.

## Report

List the commits created and any recipes skipped for producing no changes. Do not push or open a pull request unless asked.
