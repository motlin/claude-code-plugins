---
name: markdown-add-task
description: Add a self-contained task to .llm/todo.md. Use when the user asks to add one task or append work to the markdown task list.
---

# Markdown Add Task

Use the `markdown-tasks` skill for task format and script path rules.

If the user did not provide a task description, ask for one.

Expand the description into a self-contained task with all necessary context. Use multi-line format with indented details.

Run:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2"
```

Confirm that the task was added.
