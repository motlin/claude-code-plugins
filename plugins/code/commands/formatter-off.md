---
description: Scan code generator files for string concatenation blocks missing @formatter:off guards or broken by auto-formatting. Fix violations using the code-generation skill.
---

Use the `code-generation` skill to understand the formatting conventions.

Scan all Java code generator files for string concatenation blocks containing `\n` that are missing `// @formatter:off` / `// @formatter:on` guards.

For each violation found, apply the fix procedure from the skill: wrap in formatter guards and collapse each `\n`-terminated segment onto a single Java source line.

Report what was fixed when done.
