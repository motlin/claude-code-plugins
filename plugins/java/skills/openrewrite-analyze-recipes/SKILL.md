---
name: openrewrite-analyze-recipes
description: Dry-run configured OpenRewrite recipes, count and rank violations per recipe, and optionally run one selected recipe without committing. Use when asked to analyze OpenRewrite recipes, report rule violations, inspect a rewrite dry run, or compare which recipes would change the most files.
---

# Analyze OpenRewrite Recipes

Dry-run all configured OpenRewrite recipes, rank them by violation count, and optionally run one selected recipe in isolation. Follow the `java:maven-cli` skill whenever invoking Maven, and never use offline mode.

## Discover the invocation

- Find the `rewrite-maven-plugin` configuration in `pom.xml`. Record the fully-qualified `<recipe>` names inside `<activeRecipes>` and any `<activeStyles>`. If the plugin configuration sits inside a `<profile>`, add `--activate-profiles <that-profile>` to every direct Maven call.
- If a `mise.toml`, `.mise.toml`, or `.mise/` config exists, run `mise trust` first and prefix every command with `mise exec --`. Without the right JDK, the build fails with `release version NN not supported`.
- If a justfile defines `rewrite-dry-run` and `rewrite <RECIPE>` recipes, prefer them; they already activate the right profile and recipe dependencies. Otherwise use `mvn rewrite:dryRun` and `mvn rewrite:run -Drewrite.activeRecipes=<recipe>`.

## Capture the dry run

Capture the full log in `.llm/`, not just the terminal tail. It takes minutes.

```bash
mvn rewrite:dryRun 2>&1 | tee .llm/rewrite-dryrun.log | tail -20
cp ./target/rewrite/rewrite.patch .llm/rewrite-dryrun.patch
```

The dry run fails with `Applying recipes would make changes` when violations exist. That is the violation report, not an error.

If it fails with `MismatchedInputException`, `RocksdbMavenPomCache`, or `Failed to parse or resolve the Maven POM`, that is OpenRewrite's RocksDB pom-cache serialization bug (a Jackson `@ref` mismatch, usually after an OpenRewrite version bump). Rerun with `-Drewrite.pomCacheEnabled=false`. Clearing `~/.rewrite-cache` alone does not fix it; the bug recurs on the regenerated cache. Once the flag is needed, carry it into every later run.

## Count violations per recipe

Each changed file is preceded in the log by indented `[WARNING]` lines forming the tree of recipes that touched it. Count them:

```bash
grep '\[WARNING\]' .llm/rewrite-dryrun.log \
  | grep -E '^\S+\s+\[WARNING\]\s{4,}' \
  | sed 's/.*\[WARNING\] *//' \
  | sort | uniq -c | sort -rn \
  > .llm/rewrite-violations-per-rule.txt
```

This counts every recipe line in every file's tree, so a composite is counted once per file alongside each child, and a parameterized child appears with its inline options. That raw count is the ranking.

## Identify runnable leaf recipes

From each file's tree, take the most specific named leaf recipe in each branch. Prefer a named wrapper (e.g. `io.liftwizard.UpdateCopyrightYear`) over the raw parameterized child it contains (`org.openrewrite.text.FindAndReplace: {find=...}`), because a recipe shown with inline `: {options}` cannot be activated by name. Mark composites "(composite)" only when the tree context distinguishes them reliably.

## Summarize

```bash
echo "Total files changed: $(grep 'These recipes would make changes' .llm/rewrite-dryrun.log | wc -l | tr -d ' ')"
echo "Patch size: $(wc -l < .llm/rewrite-dryrun.patch) lines"
echo "Total rule violations: $(awk '{s+=$1}END{print s}' .llm/rewrite-violations-per-rule.txt)"
echo "Unique rules triggered: $(wc -l < .llm/rewrite-violations-per-rule.txt | tr -d ' ')"
```

Show these statistics and the full ranked list as a markdown table with columns `Count` and `Recipe`, composites marked.

## Run a selected recipe

Use AskUserQuestion to ask which recipe to run, if any, offering the top 3 leaf (non-composite) recipes by fully-qualified name.

Check `git status --porcelain` first. If there are uncommitted changes, warn the user and ask whether to proceed; do not stash or discard them.

`-Drewrite.activeRecipes` overrides the POM's `<activeRecipes>`, so only the selected recipe runs. Keep any mise, just, profile, and pom-cache flags found earlier.

```bash
mvn rewrite:run -Drewrite.activeRecipes=<selected.recipe.name> 2>&1 | tail -20
```

Show `git diff --stat` and `git diff` for a few representative files. Do not commit; leave the changes unstaged for review.
