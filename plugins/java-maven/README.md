# java-maven

Java and Maven tools for OpenRewrite import ordering and POM dependency management.

## Commands

### `/openrewrite-imports`
Fix OpenRewrite import ordering test failures by understanding how OpenRewrite manages imports and updating test expectations accordingly.

### `/pom-ordering`
Check Maven POM file dependency ordering using the pom-ordering skill.

## Skills

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
