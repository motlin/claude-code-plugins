---
name: markdown-do-one-task
description: Find and implement the next incomplete task from .llm/todo.md.
---

# Markdown Do One Task

Use the `markdown-tasks` skill for script path rules and task semantics.

Extract the next task:

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

If no task is returned, report that there are no incomplete tasks.

Implement only the extracted task. Ignore unrelated TODO/TASK comments in source code.

Run appropriate tests and validation. If the `build` and `git` plugins are installed, use `precommit`, `git-commit`, and `git-rebase` as appropriate.

Mark the task complete:

```bash
python <plugin-root>/scripts/task_complete.py .llm/todo.md
```
