---
name: openrewrite-recipes
description: OpenRewrite recipe authoring patterns and API best practices. Use when writing or editing OpenRewrite recipe Java source code (visitors, matchers, type checks, templates, metadata, YAML config, list transformations, at-scale validation).
---

# OpenRewrite Recipe Authoring Patterns

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

When matching a member's declaring type against the current class, check both exact match and subtype relationship. Without this, inherited members get incorrectly attributed to the superclass:

```java
// BAD: misses inherited members
if (TypeUtils.isOfType(currentType, declaringType)) { ... }

// GOOD: handles both direct and inherited members
if (TypeUtils.isOfType(currentType, declaringType) ||
        TypeUtils.isAssignableTo(declaringType.getFullyQualifiedName(), currentType)) { ... }
```

Use the FQN-based `isAssignableTo` overload to handle parameterized types correctly.

### Use `instanceof JavaType.FullyQualified` not `JavaType.Class`

`JavaType.Class` extends `JavaType.FullyQualified`, so checking for the parent type is broader and more correct:

```java
// BAD: too narrow
if (fieldType.getOwner() instanceof JavaType.Class)

// GOOD: covers more cases
if (fieldType.getOwner() instanceof JavaType.FullyQualified)
```

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

When recipes run in a composition (e.g., `Slf4jBestPractices`), earlier recipes transform the code before later ones see it. Don't handle cases that earlier recipes already cover.

Example: `RemoveUnnecessaryLogLevelGuards` should NOT treat string concatenation (`"Name: " + name`) as safe to unguard. The `ParameterizedLogging` recipe runs first and converts concatenation to parameterized form. If concatenation still exists when the guard-removal recipe runs, the guard is still needed for performance.

### Add test cases for edge cases where transformation should NOT apply

Always test that the recipe correctly _preserves_ code that should not be changed, not just that it transforms code that should be changed.

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

Java-specific recipes will also run on Kotlin files unless explicitly excluded:

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
        .imports(fqn)  // Declare the import
        .build();
```

### Always call `maybeAddImport()` after applying a template

After applying a template that uses a type, add the import to the compilation unit:

```java
Expression result = template.apply(...);
maybeAddImport(fqn);  // Add the import to the source file
```

## Visitor Patterns

### JavaVisitor vs JavaIsoVisitor

Use `JavaIsoVisitor` when returning the same LST element type you're visiting (most common for simple transformations):

```java
@Override
public J.TypeCast visitTypeCast(J.TypeCast typeCast, ExecutionContext ctx) {
    J.TypeCast tc = super.visitTypeCast(typeCast, ctx);
    // ... transform ...
    return tc;  // Still a J.TypeCast
}
```

Use `JavaVisitor` when you need to return a different LST element type (e.g., unwrapping parentheses):

```java
@Override
public J visitParentheses(J.Parentheses parentheses, ExecutionContext ctx) {
    // ... some logic ...
    return someExpression;  // Not a J.Parentheses
}
```

### Handle parenthesized expressions explicitly

When dealing with expressions that might be parenthesized, visit `J.Parentheses` nodes too.

### Preserve formatting when replacing expressions

```java
return visitedParentheses.withTree(result);  // Preserves parentheses structure and prefix
```

## Recipe Metadata

### Include RSPEC tags for SonarQube rules

```java
@Override
public Set<String> getTags() {
    return Collections.singleton("RSPEC-S3020");
}
```

### Provide accurate time estimates

Use the same time estimate from the SonarQube definition:

```java
@Override
public Duration getEstimatedEffortPerOccurrence() {
    return Duration.ofMinutes(2);
}
```

## YAML Configuration

### Add recipes to appropriate recipe collections

Don't forget to add new recipes to relevant YAML files:

```yaml
recipeList:
    - org.openrewrite.staticanalysis.CollectionToArrayShouldHaveProperType
```

Common collections:

- `common-static-analysis.yml` - General static analysis fixes
- `java-best-practices.yml` - Java-specific best practices
- `static-analysis.yml` - Broader static analysis recipes

## At-Scale Validation

### Test recipes against real-world codebases

Before submitting, run at scale against large codebases (e.g., Spring, Netflix orgs). This catches bugs unit tests miss:

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
