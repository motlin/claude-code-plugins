---
name: code-generation
description: This skill should be used when the user asks to "fix formatter-off", "fix code generation formatting", "fix auto-formatted string concatenation", "add formatter off", or when writing, reviewing, or generating Java code generators that build source code via string concatenation. Also applies proactively when creating new code generation methods or modifying existing ones — always use @formatter:off guards and the one-output-line-per-source-line convention.
---

# Code Generation Formatting

## Purpose

Java code generators that build source code via string concatenation must use `// @formatter:off` / `// @formatter:on` guards. Without these, IntelliJ's auto-formatter breaks concatenation chains across multiple lines, destroying the correspondence between Java source lines and generated output lines.

## The Rule

Each line of generated output (terminated by `\n`) must occupy a single Java source line. A new line in the Java source should only occur where there is a `\n` in the template string.

### Bad (auto-formatted)

```java
setterBody = ""
    + "            domainObject.get"
    + propNameUpper
    + "().clear();\n"
    + "            return;\n";
```

### Good (one output line per Java line)

```java
// @formatter:off
setterBody = ""
        + "            domainObject.get" + propNameUpper + "().clear();\n"
        + "            return;\n";
// @formatter:on
```

## How to Identify Violations

Search for string concatenation blocks that contain `\n` literals but are NOT wrapped in `// @formatter:off`. Common patterns:

1. **Multi-line `+` chains** where each `+` is on its own line and template variables are separated from their surrounding string literals
2. **`.collect()` lambdas** producing single-line templates that got broken across multiple lines
3. **Return statements** wrapped in parentheses `return ( "" + ... )` instead of direct `return "" + ...`

## Fix Procedure

1. Search generator files for string concatenation containing `\n` that lacks `@formatter:off` guards
2. For each violation:
    - Add `// @formatter:off` before the block
    - Collapse string concatenation so each `\n`-terminated segment is on one Java source line
    - Add `// @formatter:on` after the block
3. For `.collect()` lambdas that produce single-line templates (one `\n`), collapse the entire template string onto one line
4. For multi-line templates, each `\n`-terminated segment gets its own line with `+` continuation
5. Use the same indentation style as existing `@formatter:off` blocks in the file

## Indentation Style

Match the existing convention in each file. The typical pattern uses tabs with `+` aligned:

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

For `.collect()` lambdas with single-line output, keep it all on one line:

```java
		// @formatter:off
		String fields = properties
			.collect((p) -> "    public final " + this.getType(p) + " " + p.getName() + ";\n")
			.makeString("");
		// @formatter:on
```

## Additional Markers

When the string block contains valid Java source, add `// language=JAVA` after `// @formatter:off` to enable IntelliJ language injection for syntax highlighting inside the strings.
