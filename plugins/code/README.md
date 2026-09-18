# code

Code quality tools for comment cleanup and emoji enhancement.

## Commands

### `/code:comments`

Remove obvious and redundant comments from uncommitted code changes only.

### `/code:all-comments`

Remove obvious and redundant comments from all files in the codebase.

### `/code:emoji`

Add appropriate emoji to content to make it more engaging and easier to scan.

### `/code:formatter-off`

Scan code generator files for string concatenation blocks missing `@formatter:off` guards or broken by auto-formatting.

## Skills

### `/code:test-assertions`

Write test assertions as complete, strict deep-equality checks and rewrite existing tests to that standard. Invoke as `/code:test-assertions [file or directory]`; without a target it rewrites the test files in uncommitted changes, or all test files when the tree is clean.

### `/code:code-quality`

Code quality guidelines to follow before editing code.

### `/code:comment-cleanup`

Rules for keeping comments concise and durable, and for removing redundant ones from a diff or the whole repository.

### `/code:cli`

Shell invocation conventions for the Bash tool.

### `/code:code-generation`

`@formatter:off` guards and the one-output-line-per-source-line convention for Java code generators.

### `/code:test-data`

Keep literal values in tests self-evidently fake.
