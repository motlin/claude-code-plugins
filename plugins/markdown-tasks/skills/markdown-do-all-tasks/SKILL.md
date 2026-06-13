---
name: markdown-do-all-tasks
description: Work through all incomplete tasks in .llm/todo.md until none remain or a task is blocked.
---

# Markdown Do All Tasks

Use the `markdown-tasks` skill for script path rules and task semantics.

Repeatedly extract and implement the first incomplete task:

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

Track attempted tasks to avoid infinite loops. If a task fails, stop and report the failure; do not mark it complete.

For each task:

- Report the task being started.
- Implement only that task.
- Run appropriate validation.
- Mark it complete with `task_complete.py`.

When no incomplete tasks remain, archive the task list:

```bash
python <plugin-root>/scripts/task_archive.py .llm/todo.md
```

Report the archive path.
