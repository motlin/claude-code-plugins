---
name: markdown-sweep-todos
description: Find TODO comments in the codebase and add them to .llm/todo.md as tasks.
---

# Markdown Sweep TODOs

Use the `markdown-tasks` skill for task format and script path rules.

Search the codebase for TODO comments. For each occurrence, capture:

- File path.
- Line number.
- Full TODO text with comment markers removed.

Compose all TODO tasks before writing. Add the complete batch in one shell command by chaining one call per TODO with `&&`:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Implement TODO from <file>:<line>: <todo text>" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Implement TODO from <another-file>:<line>: <todo text>"
```

Never add a multi-TODO batch across separate shell commands. Keeping the writes together reduces the chance that concurrent sessions interleave their tasks.

Report how many TODO tasks were added.
