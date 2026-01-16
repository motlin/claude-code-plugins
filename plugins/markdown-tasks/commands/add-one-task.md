---
argument-hint: task description
description: Add a task to the project task list
model: haiku
---

Add a task to the project task list.

<description>
$ARGUMENTS
</description>

If no description was provided, ask the user for one.

## Adding a Task

1. Expand the description into a self-contained task with all necessary context
2. Use multi-line format with indented details
3. Run this command:

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2"
```

Creates the `.llm/` directory and `todo.md` file if they do not exist, and appends the new task with a `[ ]` checkbox. The script preserves all indentation in multi-line strings.

**Exit codes**: 0 (success), 1 (error)

## Task Format

The task list is in `.llm/todo.md`.

NEVER use the `Read` tool on `.llm/todo.md`. Always interact with the task list exclusively through the Python scripts.

### Task States

- `[ ]` - Not started (ready to work on)
- `[x]` - Completed
- `[!]` - Blocked after failed attempt

### Task Structure

Each task includes indented context lines with full implementation details:

- Absolute file paths
- Exact function/class names
- Code analogies to existing patterns
- Dependencies and prerequisites
- Expected outcomes

### Standalone Context

Each task is extracted and executed in isolation. Every task must contain ALL context needed to implement it. Never reference other tasks.

Confirm to the user that the task was added.
