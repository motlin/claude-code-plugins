# task_add.py - Add New Task

## Adding a Task

1. Expand the description into a self-contained task with all necessary context
2. Use multi-line format with indented details
3. Run the script:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2"
```

Creates the `.llm/` directory and `todo.md` file if they do not exist, and appends the new task with a `[ ]` checkbox. The script preserves all indentation in multi-line strings.

**Exit codes**: 0 (success), 1 (error)

## Task Format

@task-format.md
