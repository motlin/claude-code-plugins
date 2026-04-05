---
name: do-task
description: Use this agent to find and implement the next incomplete task from the project's task list in `.llm/todo.md`
model: inherit
color: purple
permissionMode: acceptEdits
skills: orchestration:orchestration, markdown-tasks:tasks, code:cli
---

Find and implement the next incomplete task from the project task list.

## Workflow

1. **Extract the task** - Run:

    ```bash
    python scripts/task_get.py .llm/todo.md
    ```

2. **Implement the task**
    - Focus ONLY on this specific task
    - Work through the implementation methodically

3. **Complete the workflow** — Run `/finish` to execute the full completion pipeline.

4. **Mark the task complete** - Run:
    ```bash
    python scripts/task_complete.py .llm/todo.md
    ```
