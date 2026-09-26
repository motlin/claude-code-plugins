---
name: openrewrite
description: OpenRewrite recipe test maintenance. Use when fixing test failures, import ordering issues, type validation problems, IDE warnings, or writing comprehensive recipe tests.
---

# OpenRewrite Recipe Tests

For recipe source code patterns, see the `java:openrewrite-recipes` skill.

## Import ordering failures

Recipe tests often fail on import order alone, not on the transformation:

```diff
-import java.util.List;
-import org.assertj.core.api.Assertions;
+import org.assertj.core.api.Assertions;
+import java.util.List;
```

If imports are missing entirely, fix the recipe: declare them on the `JavaTemplate` and call `maybeAddImport` / `maybeRemoveImport`. A template that introduces library types also needs `.contextSensitive()` and a parser classpath:

```java
JavaTemplate template = JavaTemplate
    .builder("Your.template.code()")
    .imports(
        "org.assertj.core.api.Assertions",
        "org.eclipse.collections.impl.utility.Iterate"
    )
    .contextSensitive()
    .javaParser(JavaParser.fromJavaVersion()
        .classpath("assertj-core", "eclipse-collections", "eclipse-collections-api")
    )
    .build();
```

If only the order differs, accept the order OpenRewrite produces rather than forcing your own: copy the actual output from the failure into the expected text, confirm the transformation itself is right, and rerun. OpenRewrite typically orders imports as third-party packages, blank line, `java.*` / `javax.*`, then static imports after another blank line.

```java
"""
import org.assertj.core.api.Assertions;
import org.eclipse.collections.impl.utility.Iterate;

import java.util.List;
"""
```

The `~~>` prefix ("ignore everything before this line") is not recognized in every codebase. If it fails, remove it and match exactly.

## Type validation

For tests with custom types that lack complete type information, prefer types that exist on the classpath. Disable validation only as a last resort:

```java
rewriteRun(
  spec -> spec.typeValidationOptions(TypeValidation.none()),
  java(...)
);
```

## IDE warnings

Test inputs contain intentional issues. Suppress the resulting IDE warnings with `@SuppressWarnings` on the test method, or on the class when several tests share it. Common values: `"RedundantCast"`, `"ConstantConditions"`, `"unused"`, `"unchecked"`.

## Language comments

Add `//language=java` for IDE highlighting. With a plain `java("before", "after")` call, put it before `java`. With a spec customization or several `java()` calls, put it on the individual strings.

Do not add `//language=java` to `JavaTemplate` strings containing `#{any()}` or `#{}`; they are not valid Java.

## Coverage

Cover basic cases, edge cases (custom types, fully qualified types), cases where the recipe must not change anything, import handling, and formatting preservation.
