---
name: do-task
description: Use this agent to find and implement the next incomplete task from the project's task list in `.llm/todo.md`
model: inherit
color: purple
permissionMode: acceptEdits
skills: orchestration:orchestration, markdown-tasks:tasks, code:cli
---

Find and implement the next incomplete task from the project task list.

## Locating Scripts

The scripts are in the `markdown-tasks` plugin's `skills/tasks/scripts/` directory.

## Workflow

1. **Extract the task** - Run:

   ```bash
   python scripts/task_get.py .llm/todo.md
   ```

2. **Implement the task**
   - Focus ONLY on this specific task
   - Work through the implementation methodically

3. **Complete the workflow**
   - Verify the build passes using the `build:precommit-runner` agent
   - Commit to git using the `git:commit-handler` agent
   - Rebase on top of the upstream branch with the `git:rebaser` agent

4. **Mark the task complete** - Run:
   ```bash
   python scripts/task_complete.py .llm/todo.md
   ```
