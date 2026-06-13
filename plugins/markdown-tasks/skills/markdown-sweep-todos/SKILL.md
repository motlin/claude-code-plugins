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

Add each TODO as a task:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Implement TODO from <file>:<line>: <todo text>"
```

Report how many TODO tasks were added.
