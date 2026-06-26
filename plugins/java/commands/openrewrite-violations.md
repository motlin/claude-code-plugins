---
description: Fix each violated OpenRewrite recipe in its own commit on an openrewrite-violations branch
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# OpenRewrite Violations

Create a branch named `openrewrite-violations`, then apply every configured OpenRewrite recipe that has violations one at a time, committing each recipe's changes as a separate commit with the message `Fix violations of OpenRewrite rule: <recipe>.`

If `$ARGUMENTS` is provided, use it as the branch name instead of `openrewrite-violations`.

## Require a clean working tree

Run `git status --porcelain`. If there are uncommitted changes, stop and tell the user — this command creates commits and must start clean. Do not stash or discard their work.

## Create the branch

Fetch the upstream default branch and create the new branch from it, so the commits land on top of current `main`:

```bash
git fetch origin
git switch -c openrewrite-violations origin/HEAD
```

Use a worktree (`git worktree add`) instead if the user is mid-work on another branch and you should not move their checkout.

## Determine how this repo invokes OpenRewrite

Inspect the repo before running anything:

- If a `mise.toml`, `.mise.toml`, or `.mise/` config exists, every Maven command must be prefixed with `mise exec --`, and the config must be trusted first: `mise trust`. Without the right JDK, the build fails with `release version NN not supported`.
- If a justfile defines `rewrite-dry-run` and `rewrite <RECIPE>` recipes (common in these repos), prefer them — they already activate the correct profile and recipe dependencies.
- Otherwise call the plugin directly: `mvn rewrite:dryRun` and `mvn rewrite:run -Drewrite.activeRecipes=<recipe>`. Check `pom.xml` for the `rewrite-maven-plugin`: if its configuration sits inside a `<profile>`, add `--activate-profiles <that-profile>` to every invocation.

## Enumerate the recipes that have violations

Run the dry run and capture the full log (it takes minutes):

```bash
mise exec -- just rewrite-dry-run 2>&1 | tee .llm/rewrite-dryrun.log | tail -20
```

The dry run "fails" with `Applying recipes would make changes` when violations exist — that is the signal to proceed, not an error.

If it fails instead with `MismatchedInputException` / `RocksdbMavenPomCache` / `Failed to parse or resolve the Maven POM`, that is OpenRewrite's RocksDB pom-cache serialization bug (a Jackson `@ref` mismatch, usually triggered by an OpenRewrite version bump). Add `-Drewrite.pomCacheEnabled=false` to disable the on-disk pom cache and re-run. Clearing `~/.rewrite-cache` with `trash` alone does NOT fix it — the bug recurs on the regenerated cache.

## Identify the distinct rules

In the dry-run output, each changed file is preceded by the recipe tree that produced it. Collect the set of distinct leaf recipes — the most specific fully-qualified recipe in each branch of the tree. Prefer a named recipe over a raw parametrized one: use the wrapper (e.g. `io.liftwizard.UpdateCopyrightYear`), not the bare `org.openrewrite.text.FindAndReplace: {find=...}` it contains, because a recipe carrying inline `: {options}` cannot be activated by name alone. Treat each distinct recipe as one rule. Present the list to the user before applying.

## Apply each rule and commit it

For each rule, run it in isolation. `-Drewrite.activeRecipes` overrides the POM's `<activeRecipes>` so only that one recipe runs:

```bash
mise exec -- just rewrite <recipe>
# or: mise exec -- mvn rewrite:run -Drewrite.activeRecipes=<recipe> -Drewrite.pomCacheEnabled=false
```

Then commit only if it changed something:

```bash
if [ -n "$(git status --porcelain)" ]; then
  git commit -am "Fix violations of OpenRewrite rule: <recipe>."
fi
```

Skip recipes that produce no changes — an earlier rule may have already covered them. Never create an empty commit. Keep a stable order; each rule runs against the tree left by the previous commits.

## Verify the cumulative result

After all commits, build and test the whole project (`mise exec -- just test`, or `mvn verify`) to confirm the applied recipes compile and pass. If a recipe produced non-compiling or failing code, find the offending commit with `git log --oneline`, then fix it with a follow-up edit amended into that commit or drop the commit. A recipe applying cleanly in isolation can still interact badly with the cumulative tree, so this final check is mandatory.

## Report

List the commits created (one per rule) and any rules that were skipped because they produced no changes. Do not push or open a pull request unless the user asks.
