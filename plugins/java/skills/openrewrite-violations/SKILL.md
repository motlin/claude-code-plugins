---
name: openrewrite-violations
description: Apply every configured OpenRewrite recipe with violations on a dedicated branch, creating one commit per named leaf recipe and verifying the cumulative result. Use when asked to fix all OpenRewrite violations, create an OpenRewrite cleanup branch, or commit recipe changes separately.
---

# Fix OpenRewrite Violations

Create a branch named `openrewrite-violations`, then apply every configured OpenRewrite recipe that has violations one at a time, committing each recipe's changes as a separate commit with the message `Fix violations of OpenRewrite rule: <recipe>.`

If the user supplies a branch name, use it instead of `openrewrite-violations`.

Follow the `java:maven-cli` skill for every Maven invocation and the `git:git-workflow` skill for every commit; delegate each commit to the `git:commit-handler` agent.

## Start from a clean checkout

Run `git status --porcelain`. If there are uncommitted changes, stop and tell the user: this workflow creates commits and must start clean. Do not stash, discard, or absorb their work.

Fetch the upstream default branch and create the new branch from it, so the commits land on top of current `main`:

```bash
git fetch origin
git switch -c openrewrite-violations origin/HEAD
```

Use a worktree (`git worktree add`) instead if the user is mid-work on another branch and you should not move their checkout.

## Discover the repository workflow

Inspect the repo before running anything:

- If a `mise.toml`, `.mise.toml`, or `.mise/` config exists, every Maven command must be prefixed with `mise exec --`, and the config must be trusted first: `mise trust`. Without the right JDK, the build fails with `release version NN not supported`.
- If a justfile defines `rewrite-dry-run` and `rewrite <RECIPE>` recipes (common in these repos), prefer them; they already activate the correct profile and recipe dependencies.
- Otherwise call the plugin directly: `mvn rewrite:dryRun` and `mvn rewrite:run -Drewrite.activeRecipes=<recipe>`. Check `pom.xml` for the `rewrite-maven-plugin`: if its configuration sits inside a `<profile>`, add `--activate-profiles <that-profile>` to every invocation.
- Never use Maven offline mode.

## Enumerate the recipes that have violations

Run the dry run and capture the full log in `.llm/rewrite-dryrun.log` (it takes minutes):

```bash
mise exec -- just rewrite-dry-run 2>&1 | tee .llm/rewrite-dryrun.log | tail -20
```

The dry run "fails" with `Applying recipes would make changes` when violations exist. That is the signal to proceed, not an error.

If it fails instead with `MismatchedInputException` / `RocksdbMavenPomCache` / `Failed to parse or resolve the Maven POM`, that is OpenRewrite's RocksDB pom-cache serialization bug (a Jackson `@ref` mismatch, usually triggered by an OpenRewrite version bump). Add `-Drewrite.pomCacheEnabled=false` to disable the on-disk pom cache and re-run. Clearing `~/.rewrite-cache` with `trash` alone does NOT fix it; the bug recurs on the regenerated cache. Once the flag is needed, carry it into every per-recipe run as well.

## Identify runnable recipes

In the dry-run output, each changed file is preceded by the recipe tree that produced it. Collect the set of distinct leaf recipes: the most specific fully-qualified recipe in each branch of the tree. Prefer a named recipe over a raw parametrized one: use the wrapper (e.g. `io.liftwizard.UpdateCopyrightYear`), not the bare `org.openrewrite.text.FindAndReplace: {find=...}` it contains, because a recipe carrying inline `: {options}` cannot be activated by name alone. Treat each distinct recipe as one rule.

Present the stable ordered list to the user before applying changes.

## Apply and commit each recipe

For each recipe in order, run it in isolation. `-Drewrite.activeRecipes` overrides the POM's `<activeRecipes>` so only that one recipe runs:

```bash
mise exec -- just rewrite <recipe>
# or: mise exec -- mvn rewrite:run -Drewrite.activeRecipes=<recipe> -Drewrite.pomCacheEnabled=false
```

Then:

- Skip the recipe when it produces no changes; an earlier recipe may have already covered it. Never create an empty commit.
- Inspect and stage only the files changed by that recipe.
- Run the repository's required checks for the change.
- Commit with `Fix violations of OpenRewrite rule: <fully-qualified-recipe>.` through the `git:commit-handler` agent.

Keep a stable order and every recipe's changes isolated in its own commit; each rule runs against the tree left by the previous commits.

## Verify the cumulative branch

After all commits, build and test the whole project (`mise exec -- just test`, or `mvn verify`) to confirm the applied recipes compile and pass. A recipe applying cleanly in isolation can still interact badly with the cumulative tree, so this final check is mandatory.

If a recipe produced non-compiling or failing code, find the offending commit with `git log --oneline`, then either fix it with a follow-up edit folded into that recipe's commit (without combining unrelated rules) or drop the commit.

## Report

List the commits created (one per rule) and any rules that were skipped because they produced no changes. Do not push or open a pull request unless the user asks.
