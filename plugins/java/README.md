# java

Java and Maven tooling: OpenRewrite recipes, POM dependency ordering, Maven CLI habits, and Liquibase lock cleanup.

- `/java:maven-cli`: when to use `-am`, and why to avoid `-o`
- `/java:pom-ordering`: check or enforce POM dependency order and region comments
- `/java:openrewrite`: fix OpenRewrite recipe tests
- `/java:openrewrite-recipes`: recipe authoring patterns
- `/java:openrewrite-analyze-recipes`: dry-run and rank recipes by violation count
- `/java:openrewrite-violations`: one commit per recipe on a cleanup branch
- `/java:liquibase-lock-resolver` (skill and agent): clear stale H2 databases behind Liquibase lock errors
