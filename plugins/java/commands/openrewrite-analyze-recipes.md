---
description: Dry-run all configured OpenRewrite recipes and rank them by violation count
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, AskUserQuestion
---

# OpenRewrite Analyze Recipes

Dry-run all configured OpenRewrite recipes, rank them by number of violations, and present the ranked list. Optionally run a selected recipe in isolation.

## Parse active recipes from the POM

Find the `rewrite-maven-plugin` configuration in `pom.xml` and extract the list of `<recipe>` elements inside `<activeRecipes>`. Save this list for later; you'll need the fully-qualified recipe names.

Also extract the `<activeStyles>` entries if any exist.

## Run the dry run

```bash
mvn rewrite:dryRun 2>&1 | tee .llm/rewrite-dryrun.log | tail -20
```

This may take several minutes. The dry run produces:

- Console output with `[WARNING]` lines listing which recipes would change which files
- A patch file at `./target/rewrite/rewrite.patch`

## Save the patch

```bash
cp ./target/rewrite/rewrite.patch .llm/rewrite-dryrun.patch
```

## Count violations per recipe

The Maven log contains indented `[WARNING]` lines with recipe names. Extract and count them:

```bash
grep '\[WARNING\]' .llm/rewrite-dryrun.log \
  | grep -E '^\S+\s+\[WARNING\]\s{4,}' \
  | sed 's/.*\[WARNING\] *//' \
  | sort | uniq -c | sort -rn \
  > .llm/rewrite-violations-per-rule.txt
```

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
- The full ranked table from `.llm/rewrite-violations-per-rule.txt` formatted as a markdown table with columns `Count` and `Recipe`
- Mark composite recipes (recipes that contain other recipes) with "(composite)" if you can identify them from the log's tree structure

## Ask which recipe to run

Use AskUserQuestion to ask which recipe to run. Offer the top 3 leaf (non-composite) recipes as options, using their fully-qualified names. The user may also type any recipe name.

## Run the selected recipe

Before running, ensure the working tree is clean. If there are uncommitted changes, warn the user and ask whether to proceed.

Run the selected recipe in isolation:

```bash
mvn rewrite:run -Drewrite.activeRecipes=<selected.recipe.name> 2>&1 | tail -20
```

Note: the `-Drewrite.activeRecipes` flag overrides the POM's `<activeRecipes>`, so only the selected recipe runs.

## Show results

After the recipe runs, show:

- `git diff --stat` to summarize what changed
- A sample of the actual changes (`git diff` on a few representative files)

Do NOT commit the changes. Leave them unstaged for the user to review.
