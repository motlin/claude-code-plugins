# java

Java and Maven tools for OpenRewrite import ordering and POM dependency management.

## Commands

### `/openrewrite-analyze-recipes`

Dry-run all configured OpenRewrite recipes, rank them by violation count, and optionally run a selected recipe in isolation.

### `/pom-ordering`

Check Maven POM file dependency ordering using the pom-ordering skill.

## Skills

### `openrewrite-recipes`

Create new OpenRewrite recipes for Java codebases, including recipe YAML configuration, unit tests, and integration with the existing rewrite module.

### `pom-ordering`

Enforce Maven POM dependency ordering rules with specific groupId ordering and region comment structure.

Ordering hierarchy:

1. First-party (${project.groupId})
2. cool.klass
3. io.liftwizard
4. org.eclipse.collections
5. io.dropwizard
6. Other third-party libraries
7. Jakarta
