---
description: Scan code generator files for string concatenation blocks missing @formatter:off guards or broken by auto-formatting. Fix violations using the code-generation skill.
---

Use the `code:code-generation` skill to find and fix every Java code generator string concatenation block containing `\n` that lacks `// @formatter:off` / `// @formatter:on` guards. Report what was fixed.
