---
name: openrewrite-violations
description: Apply every configured OpenRewrite recipe with violations on a dedicated branch, creating one commit per named leaf recipe and verifying the cumulative result. Use when asked to fix all OpenRewrite violations, create an OpenRewrite cleanup branch, or commit recipe changes separately.
---

# Fix OpenRewrite Violations

Follow the Maven CLI skill for every Maven invocation and the repository's git workflow and commit skills for every commit.

## Start from a clean checkout

Require `git status --porcelain` to be empty. Do not stash, discard, or absorb existing work.

Use the branch name supplied by the user, or `openrewrite-violations` by default. Fetch the upstream default branch and create the branch from its current tip. Prefer a new worktree when switching the user's active checkout would disrupt other work.

## Discover the repository workflow

- Use mise for Maven and just commands when the repository configures it; trust the checked-in config first when required.
- Prefer repository-provided `rewrite-dry-run` and `rewrite <recipe>` commands.
- Otherwise inspect the rewrite Maven plugin, including profiles, and invoke `rewrite:dryRun` or `rewrite:run` directly.
- Never use Maven offline mode.

Capture the complete dry-run log in `.llm/rewrite-dryrun.log`. Treat "Applying recipes would make changes" as the expected violation signal. For a `RocksdbMavenPomCache` serialization failure, add `-Drewrite.pomCacheEnabled=false` and rerun.

## Identify runnable recipes

Read the recipe tree preceding each changed file and collect distinct, most-specific named leaf recipes. Prefer a named wrapper over a raw parameterized recipe with inline options, which cannot be activated by name alone.

Present the stable ordered list before applying changes.

## Apply and commit each recipe

For each recipe in order:

- Run that recipe alone with the repository command or `mvn rewrite:run -Drewrite.activeRecipes=<fully-qualified-recipe>`.
- Inspect and stage only the files changed by that recipe.
- Skip the recipe when it produces no changes; an earlier recipe may have covered it.
- Run the repository's required checks for the change.
- Commit with `Fix violations of OpenRewrite rule: <fully-qualified-recipe>.`

Never create an empty commit. Keep every recipe's changes isolated in its own commit and do not push unless the user asks.

## Verify the cumulative branch

After all recipes, run the full project build and test workflow. If the combined result fails, identify the responsible recipe commit, correct its changes, and fold the correction into that recipe's commit without combining unrelated rules.

Report created commits and skipped recipes.
