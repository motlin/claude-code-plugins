---
argument-hint: task description
description: Add a task to the project task list
---

➕ Add a task to the project task list.

Takes the user's description and adds it to `.llm/todo.md` as an incomplete task.

If the user provided a description, it will appear here:

<description>
$ARGUMENTS
</description>

## Steps

- Extract the description from the user's input
- If no description was provided, ask the user for one
- Add the task using the `@tasks` skill:
  ```bash
  python3 ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_add.py .llm/todo.md "<description>"
  ```
- The script will:
  - Create `.llm/` directory if it doesn't exist
  - Create `todo.md` file if it doesn't exist
  - Append the new task with `[ ]` checkbox
- Confirm to the user that the task was added

## Task context

The task list is in `.llm/todo.md`. The format is:

```markdown
- `[ ]` - Not started
- `[x]` - Completed
```

## Important notes

- The description should be clear and actionable
- Don't include the checkbox syntax in the description (the script adds it)
- The `.llm/` directory is gitignored via `.git/info/exclude`
