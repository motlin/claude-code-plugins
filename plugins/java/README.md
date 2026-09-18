# java

Java and Maven tools for OpenRewrite import ordering and POM dependency management.

## Skills

Workflows are invoked as `/java:<name>`; Claude also loads them itself when a task matches.

### `/java:openrewrite-analyze-recipes`

Dry-run all configured OpenRewrite recipes, rank them by violation count, and optionally run a selected recipe in isolation, leaving the changes unstaged for review. Invoke as `/java:openrewrite-analyze-recipes`.

### `/java:openrewrite-violations`

Create an `openrewrite-violations` branch (or a branch named by the user) from the upstream default branch, apply every configured OpenRewrite recipe that has violations one at a time with one commit per recipe, then build and test the cumulative result. Invoke as `/java:openrewrite-violations`.

### `/java:maven-cli`

Maven CLI invocation patterns: when `-am` is required, why `-o` (offline) hides bugs in multi-worktree setups, and how to verify compile/test cleanly without trusting stale `~/.m2` artifacts.

### `/java:openrewrite-recipes`

Create new OpenRewrite recipes for Java codebases, including recipe YAML configuration, unit tests, and integration with the existing rewrite module.

### `/java:pom-ordering`

Enforce Maven POM dependency ordering rules with specific groupId ordering and region comment structure. Invoke as `/java:pom-ordering` to check the `pom.xml` files with local modifications, or all of them when none are modified.

Ordering hierarchy:

1. First-party (${project.groupId})
2. cool.klass
3. io.liftwizard
4. org.eclipse.collections
5. io.dropwizard
6. Other third-party libraries
7. Jakarta
