---
name: markdown-plan-tasks
description: Convert a planning discussion into self-contained tasks in .llm/todo.md.
---

# Markdown Plan Tasks

Use at the end of a planning discussion when the implementation has not started.

Use the `markdown-tasks` skill for task format and script path rules.

Create tasks that are fully self-contained. Each task should include:

- Absolute file paths.
- Exact class, function, or command names.
- Existing patterns to follow.
- Concrete implementation details.
- Dependencies and prerequisites.
- Expected outcome.

Compose every task before writing. Add the complete batch in one shell command by chaining one call per task with `&&`:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Another task
  Standalone context"
```

Never add a multi-task batch across separate shell commands. Keeping the writes together reduces the chance that concurrent sessions interleave their tasks.

Report how many tasks were created.
