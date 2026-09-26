---
name: markdown-add-task
description: Add a self-contained task to .llm/todo.md. Use when the user asks to add one task or append work to the markdown task list.
---

# Markdown Add Task

Use the `markdown-tasks:tasks` skill for task format and script path rules. `<plugin-root>` is `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, it is the plugin root that contains this `skills/markdown-add-task/SKILL.md` file.

If the user did not provide a task description, ask for one.

Expand the description into a self-contained task, with details on indented lines:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2"
```

Confirm that the task was added.
