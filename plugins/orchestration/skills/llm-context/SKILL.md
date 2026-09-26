---
name: llm-context
description: Guidelines for working with LLM context stored in the .llm/ directory.
---

# LLM Context Guidelines

The `.llm/` directory at the root of a git repository holds extra context for LLMs.

- `.llm/` is not tracked. If it has untracked content, make sure it is listed in `.git/info/exclude`.
- `.llm/todo.md`, when present, is the current task list. Use the `markdown-tasks:tasks` skill for it, and edit it as plans change to keep it in sync.
- Everything else in `.llm/` is read-only reference, such as git clones of tools and saved documentation.
