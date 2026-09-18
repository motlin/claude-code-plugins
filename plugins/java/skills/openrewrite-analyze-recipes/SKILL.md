---
name: openrewrite-analyze-recipes
description: Dry-run configured OpenRewrite recipes, count and rank violations per recipe, and optionally run one selected recipe without committing. Use when asked to analyze OpenRewrite recipes, report rule violations, inspect a rewrite dry run, or compare which recipes would change the most files.
---

# Analyze OpenRewrite Recipes

Dry-run all configured OpenRewrite recipes, rank them by number of violations, present the ranked list, and optionally run one selected recipe in isolation. Inspect the repository before choosing commands. Follow the `java:maven-cli` skill whenever invoking Maven.

## Discover the invocation

- Find the `rewrite-maven-plugin` configuration in `pom.xml` and record the `<recipe>` elements inside `<activeRecipes>` (you need the fully-qualified names later) and any `<activeStyles>` entries.
- Prefer repository-provided `just` recipes when they configure profiles, dependencies, or toolchains.
- Prefix commands with `mise exec --` when the repository uses mise, and trust the checked-in config first when required.
- When calling Maven directly, activate any profile that contains the rewrite plugin.
- Never use Maven offline mode for this workflow.

## Capture the dry run

Create `.llm/` when needed and capture the complete output rather than only the terminal tail. Use the repository command or the equivalent Maven goal:

```bash
mvn rewrite:dryRun 2>&1 | tee .llm/rewrite-dryrun.log | tail -20
```

This may take several minutes. The dry run produces:

- Console output with `[WARNING]` lines listing which recipes would change which files
- A patch file at `./target/rewrite/rewrite.patch`

Treat OpenRewrite's "Applying recipes would make changes" result as a successful violation report. If the run fails with a `RocksdbMavenPomCache` serialization error, rerun with `-Drewrite.pomCacheEnabled=false`; clearing the cache alone does not prevent recurrence.

Save the patch when it exists:

```bash
cp ./target/rewrite/rewrite.patch .llm/rewrite-dryrun.patch
```

## Count violations per recipe

The Maven log contains indented `[WARNING]` lines with recipe names: each changed file is preceded by the tree of recipes that touched it. Extract and count them:

```bash
grep '\[WARNING\]' .llm/rewrite-dryrun.log \
  | grep -E '^\S+\s+\[WARNING\]\s{4,}' \
  | sed 's/.*\[WARNING\] *//' \
  | sort | uniq -c | sort -rn \
  > .llm/rewrite-violations-per-rule.txt
```

This counts every recipe line in every file's tree, so a composite recipe is counted once per file alongside each of its children, and a parameterized child appears with its inline options. That raw count is the ranking: it feeds the summary statistics and the ranked table.

For choosing a recipe to run, read the tree per changed file and identify the most specific named leaf recipe in each branch. Prefer a named wrapper over a raw parameterized child recipe, because a child displayed with inline `: {options}` cannot be activated by name alone. Mark composite recipes (recipes that contain other recipes) with "(composite)" only when the log provides enough tree context to distinguish them reliably.

## Compute summary statistics

```bash
echo "Total files changed: $(grep 'These recipes would make changes' .llm/rewrite-dryrun.log | wc -l | tr -d ' ')"
echo "Patch size: $(wc -l < .llm/rewrite-dryrun.patch) lines"
echo "Total rule violations: $(awk '{s+=$1}END{print s}' .llm/rewrite-violations-per-rule.txt)"
echo "Unique rules triggered: $(wc -l < .llm/rewrite-violations-per-rule.txt | tr -d ' ')"
```

## Present the ranked list

Show the user:

- The summary statistics
- The full ranked table from `.llm/rewrite-violations-per-rule.txt` formatted as a markdown table with columns `Count` and `Recipe`, with composites marked "(composite)" where identified

## Ask which recipe to run

Use AskUserQuestion to ask which recipe to run, if any. Offer the top 3 leaf (non-composite) recipes as options, using their fully-qualified names. The user may also type any recipe name.

## Run the selected recipe

Before running, check the working tree with `git status --porcelain`. If there are uncommitted changes, warn the user and ask whether to proceed; do not stash or discard their changes.

Run only the selected recipe. The `-Drewrite.activeRecipes` flag overrides the POM's `<activeRecipes>`, so only the selected recipe runs:

```bash
mvn rewrite:run -Drewrite.activeRecipes=<selected.recipe.name> 2>&1 | tail -20
```

Preserve any repository-specific mise, just, profile, and pom-cache flags discovered earlier.

## Show results

After the recipe runs, show:

- `git diff --stat` to summarize what changed
- A sample of the actual changes (`git diff` on a few representative files)

Do NOT commit the changes. Leave them unstaged for the user to review.
