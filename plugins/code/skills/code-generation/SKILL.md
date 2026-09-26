---
name: code-generation
description: Formatting rules for Java code generators that build source code via string concatenation. Use when the user asks to "fix formatter-off", "fix code generation formatting", "fix auto-formatted string concatenation", or "add formatter off", and proactively when writing, reviewing, or modifying a code generation method.
---

# Code Generation Formatting

Java code generators that build source via string concatenation need `// @formatter:off` / `// @formatter:on` guards. Without them, IntelliJ's formatter splits concatenation chains and breaks the correspondence between Java source lines and generated output lines.

## The rule

Each `\n`-terminated line of generated output occupies exactly one Java source line. A Java line break occurs only where the template has a `\n`.

Bad (auto-formatted):

```java
setterBody = ""
    + "            domainObject.get"
    + propNameUpper
    + "().clear();\n"
    + "            return;\n";
```

Good:

```java
// @formatter:off
setterBody = ""
        + "            domainObject.get" + propNameUpper + "().clear();\n"
        + "            return;\n";
// @formatter:on
```

## Finding violations

Look for concatenation blocks containing `\n` literals that are not inside `// @formatter:off`. Typical shapes:

- Multi-line `+` chains with template variables split from their surrounding string literals.
- `.collect()` lambdas whose single-line template was broken across lines.
- `return ( "" + ... )` wrapped in parentheses instead of `return "" + ...`.

## Fixing

Wrap the block in `// @formatter:off` and `// @formatter:on`, and collapse each `\n`-terminated segment onto one line with `+` continuation. A `.collect()` lambda with a single-line template goes entirely on one line. When the strings contain valid Java source, add `// language=JAVA` after `// @formatter:off` for IntelliJ language injection.

Match the indentation of existing `@formatter:off` blocks in the file. The usual pattern is tabs with aligned `+`:

```java
		// @formatter:off
		// language=JAVA
		return ""
				+ "package " + packageName + ";\n"
				+ "\n"
				+ "public class " + className + "\n"
				+ "{\n"
				+ "}\n";
		// @formatter:on
```

```java
		// @formatter:off
		String fields = properties
			.collect((p) -> "    public final " + this.getType(p) + " " + p.getName() + ";\n")
			.makeString("");
		// @formatter:on
```
