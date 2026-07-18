---
name: openrewrite-analyze-recipes
description: Dry-run configured OpenRewrite recipes, count and rank violations, and optionally run one selected recipe without committing. Use when asked to analyze OpenRewrite recipes, report rule violations, inspect a rewrite dry run, or compare which recipes would change the most files.
---

# Analyze OpenRewrite Recipes

Inspect the repository before choosing commands. Follow the Maven CLI skill whenever invoking Maven.

## Discover the invocation

- Read the `rewrite-maven-plugin` configuration and record `<activeRecipes>` and `<activeStyles>`.
- Prefer repository-provided `just` recipes when they configure profiles, dependencies, or toolchains.
- Prefix commands with `mise exec --` when the repository uses mise, and trust the checked-in config first when required.
- When calling Maven directly, activate any profile that contains the rewrite plugin.
- Never use Maven offline mode for this workflow.

## Capture the dry run

Create `.llm/` when needed and capture the complete output rather than only the terminal tail. Use the repository command or the equivalent Maven goal:

```bash
mvn rewrite:dryRun 2>&1 | tee .llm/rewrite-dryrun.log
```

Treat OpenRewrite's "Applying recipes would make changes" result as a successful violation report. If the run fails with a `RocksdbMavenPomCache` serialization error, rerun with `-Drewrite.pomCacheEnabled=false`; clearing the cache alone does not prevent recurrence.

Copy `target/rewrite/rewrite.patch` to `.llm/rewrite-dryrun.patch` when the patch exists.

## Rank violations

Parse the recipe tree associated with every changed file. Count the most specific named leaf recipe in each branch. Prefer a named wrapper over a raw parameterized child recipe because a child displayed with inline options cannot be activated by name alone.

Save a two-column count and fully qualified recipe report in `.llm/rewrite-violations-per-rule.txt`. Report:

- Total changed files
- Patch line count
- Total violations
- Unique triggered recipes
- Every recipe ranked by count

Mark composite recipes only when the log provides enough tree context to distinguish them reliably.

## Optionally run one recipe

Present the highest-ranked leaf recipes and ask the user which recipe, if any, to apply. Before applying it, require a clean working tree; do not stash or discard changes.

Run only the selected recipe. The active-recipes property overrides the POM configuration:

```bash
mvn rewrite:run -Drewrite.activeRecipes=<fully-qualified-recipe>
```

Preserve any repository-specific mise, just, profile, and pom-cache flags discovered earlier. Show `git diff --stat` and representative diffs afterward. Do not commit the changes.
