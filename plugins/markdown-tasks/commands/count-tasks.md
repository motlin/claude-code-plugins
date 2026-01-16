---
description: Display the number of open tasks in the project task list
model: haiku
---

Count and display the number of open tasks in the project task list.

Run the following command:

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/task_count.py .llm/todo.md
```

Report the result to the user in a clear, concise format like:

- "You have N open tasks" if there are tasks
- "No open tasks" if the count is 0
