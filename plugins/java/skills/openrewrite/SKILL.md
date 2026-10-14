---
name: openrewrite
description: OpenRewrite recipe authoring and testing.
---

# OpenRewrite Recipes

## MethodMatcher

### Use wildcards instead of enumerating methods

```java
// BAD: separate matcher per variant
private static final MethodMatcher IS_TRACE_ENABLED = new MethodMatcher("org.slf4j.Logger isTraceEnabled()");
private static final MethodMatcher IS_DEBUG_ENABLED = new MethodMatcher("org.slf4j.Logger isDebugEnabled()");
// ... repeated for info, warn, error, plus marker overloads = 10 matchers

// GOOD: single wildcard matcher
private static final MethodMatcher IS_X_ENABLED = new MethodMatcher("org.slf4j.Logger is*Enabled(..)");
```

This also simplifies `Preconditions.check()`:

```java
// BAD
Preconditions.check(or(
    new UsesMethod<>(IS_TRACE_ENABLED),
    new UsesMethod<>(IS_DEBUG_ENABLED),
    // ... 8 more
), visitor);

// GOOD
Preconditions.check(new UsesMethod<>(IS_X_ENABLED), visitor);
```

### Use MethodMatcher for method+type validation

Instead of manually checking method name and receiver type:

```java
// BAD
if (!"getMessage".equals(method.getSimpleName())) return false;
Expression select = method.getSelect();
if (select == null) return false;
return TypeUtils.isAssignableTo("java.lang.Throwable", select.getType());

// GOOD
private static final MethodMatcher GET_MESSAGE = new MethodMatcher("java.lang.Throwable getMessage()");
// then: GET_MESSAGE.matches(argument)
```

## TypeUtils

### Use `isOfClassType()` instead of manual FQN comparison

```java
// BAD
JavaType.FullyQualified type = TypeUtils.asFullyQualified(select.getType());
return type != null && "org.slf4j.Logger".equals(type.getFullyQualifiedName());

// GOOD
TypeUtils.isOfClassType(select.getType(), "org.slf4j.Logger")
```

### Use `TypeUtils.isOfType()` instead of FQN string equality

```java
// BAD
currentType.getFullyQualifiedName().equals(targetType.getFullyQualifiedName())

// GOOD
TypeUtils.isOfType(currentType, targetType)
```

### Handle inheritance with `isAssignableTo()`

When matching a member's declaring type against the current class, check both exact match and subtype. Otherwise inherited members get attributed to the superclass:

```java
// BAD: misses inherited members
if (TypeUtils.isOfType(currentType, declaringType)) { ... }

// GOOD: handles both direct and inherited members
if (TypeUtils.isOfType(currentType, declaringType) ||
        TypeUtils.isAssignableTo(declaringType.getFullyQualifiedName(), currentType)) { ... }
```

Use the FQN-based `isAssignableTo` overload to handle parameterized types correctly.

### Use `instanceof JavaType.FullyQualified` not `JavaType.Class`

`JavaType.Class` extends `JavaType.FullyQualified`, so `instanceof JavaType.Class` is too narrow for checks like `fieldType.getOwner()`.

## ListUtils for Statement Transformations

### Use `ListUtils.flatMap()` instead of manual ArrayList + modified flag

```java
// BAD
List<Statement> newStatements = new ArrayList<>();
boolean modified = false;
for (Statement stmt : visited.getStatements()) {
    if (shouldTransform(stmt)) {
        newStatements.addAll(extractStatements(stmt));
        modified = true;
    } else {
        newStatements.add(stmt);
    }
}
if (modified) return visited.withStatements(newStatements);
return visited;

// GOOD
return visited.withStatements(ListUtils.flatMap(visited.getStatements(), stmt -> {
    if (shouldTransform(stmt)) {
        return extractStatements(stmt); // return List = replace with multiple
    }
    return stmt; // return single item = keep as-is
}));
```

### Use `ListUtils.map()` and `ListUtils.mapFirst()` for whitespace adjustments

```java
List<Statement> bodyStatements = ListUtils.map(
    extractStatements(ifStmt.getThenPart()),
    st -> st.withPrefix(Space.build(whitespace, emptyList())));
return ListUtils.mapFirst(bodyStatements,
    first -> first.withPrefix(ifStmt.getPrefix()));
```

## Recipe Composition

### Don't duplicate logic handled by earlier recipes

In a composition (e.g., `Slf4jBestPractices`), earlier recipes transform the code before later ones see it. Don't handle cases an earlier recipe already covers.

Example: `RemoveUnnecessaryLogLevelGuards` should not treat string concatenation (`"Name: " + name`) as safe to unguard. The `ParameterizedLogging` recipe runs first and converts concatenation to parameterized form. If concatenation still exists when the guard-removal recipe runs, the guard is still needed for performance.

## AST Construction

### Use `JavaElementFactory` for common nodes

```java
// BAD: verbose manual construction
new J.Identifier(Tree.randomId(), Space.EMPTY, Markers.EMPTY, emptyList(), "this", ownerType, null)

// GOOD: factory method
JavaElementFactory.newThis(ownerType)
```

### Use `Flag` enum and modifier helpers instead of magic bitmasks

```java
// BAD: magic number
(fieldType.getFlagsBitMap() & 0x0008L) != 0

// GOOD: readable API
fieldType.hasFlags(Flag.Static)
method.hasModifier(J.Modifier.Type.Static)
```

## Language Scoping

### Exclude non-target languages from Java-specific recipes

Java-specific recipes also run on Kotlin files unless excluded:

```java
@Override
public TreeVisitor<?, ExecutionContext> getVisitor() {
    return Preconditions.check(
        Preconditions.not(new KotlinFileChecker<>()),
        new MyJavaVisitor()
    );
}
```

## JavaTemplate Usage

### Declare imports when the template introduces types

```java
JavaTemplate template = JavaTemplate.builder("#{any()}.toArray(new #{}[0])")
        .imports(fqn)
        .build();
```

A template that introduces library types also needs `.contextSensitive()` and a parser classpath:

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

### Call `maybeAddImport()` after applying a template

```java
Expression result = template.apply(...);
maybeAddImport(fqn);
```

Call `maybeRemoveImport()` for types the template no longer uses.

## Visitor Patterns

### JavaVisitor vs JavaIsoVisitor

Use `JavaIsoVisitor` when returning the same LST element type you visit. Use `JavaVisitor` when returning a different type, such as unwrapping `J.Parentheses` into its inner expression.

### Handle parenthesized expressions

When an expression might be parenthesized, visit `J.Parentheses` nodes too. To replace the inner expression while keeping the parentheses and prefix, use `visitedParentheses.withTree(result)`.

## Recipe Metadata

### Include RSPEC tags for SonarQube rules

```java
@Override
public Set<String> getTags() {
    return Collections.singleton("RSPEC-S3020");
}
```

### Use the SonarQube time estimate

```java
@Override
public Duration getEstimatedEffortPerOccurrence() {
    return Duration.ofMinutes(2);
}
```

## YAML Configuration

### Add new recipes to recipe collections

```yaml
recipeList:
    - org.openrewrite.staticanalysis.CollectionToArrayShouldHaveProperType
```

Common collections:

- `common-static-analysis.yml` - General static analysis fixes
- `java-best-practices.yml` - Java-specific best practices
- `static-analysis.yml` - Broader static analysis recipes

## At-Scale Validation

Before submitting, run recipes at scale against large codebases (e.g., the Spring or Netflix orgs). This catches bugs unit tests miss:

- Inherited members being incorrectly qualified (e.g., `SuperClass.this.method()` instead of `this.method()`)
- Recipes accidentally modifying Kotlin files (see Language Scoping above)

## Code Style

- Explicit imports over wildcards (`java.util.List` not `java.util.*`)
- Static imports for `Collections.emptyList()` and `singletonList()`
- `@Nullable` from `org.jspecify.annotations` on methods that can return null
- Don't add `@NonNull` on parameters (non-null is the default)
- Inline small single-use helper methods rather than creating many tiny private methods
- Ternary for simple conditional returns
- Pass pre-validated/cast values as parameters rather than re-checking inside helper methods

## Recipe Tests

### Import ordering failures

Recipe tests often fail on import order alone, not on the transformation:

```diff
-import java.util.List;
-import org.assertj.core.api.Assertions;
+import org.assertj.core.api.Assertions;
+import java.util.List;
```

If imports are missing entirely, fix the recipe: declare them on the `JavaTemplate` and call `maybeAddImport` / `maybeRemoveImport`, as described under JavaTemplate Usage above.

If only the order differs, accept the order OpenRewrite produces rather than forcing your own: copy the actual output from the failure into the expected text, confirm the transformation itself is right, and rerun. OpenRewrite typically orders imports as third-party packages, blank line, `java.*` / `javax.*`, then static imports after another blank line.

```java
"""
import org.assertj.core.api.Assertions;
import org.eclipse.collections.impl.utility.Iterate;

import java.util.List;
"""
```

The `~~>` prefix ("ignore everything before this line") is not recognized in every codebase. If it fails, remove it and match exactly.

### Type validation

For tests with custom types that lack complete type information, prefer types that exist on the classpath. Disable validation only as a last resort:

```java
rewriteRun(
  spec -> spec.typeValidationOptions(TypeValidation.none()),
  java(...)
);
```

### IDE warnings

Test inputs contain intentional issues. Suppress the resulting IDE warnings with `@SuppressWarnings` on the test method, or on the class when several tests share it. Common values: `"RedundantCast"`, `"ConstantConditions"`, `"unused"`, `"unchecked"`.

### Language comments

Add `//language=java` for IDE highlighting. With a plain `java("before", "after")` call, put it before `java`. With a spec customization or several `java()` calls, put it on the individual strings.

Do not add `//language=java` to `JavaTemplate` strings containing `#{any()}` or `#{}`; they are not valid Java.

### Coverage

Cover basic cases, edge cases (custom types, fully qualified types), cases where the recipe must not change anything, import handling, and formatting preservation.
