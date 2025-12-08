---
description: Find and implement the next incomplete task from the project task list
---

Find and implement the next incomplete task from the project task list.

## Task Implementation Workflow

**CRITICAL**: Do NOT explore or search the plugin directory. Run bash commands exactly as shown.

### Steps

1. **Extract the task** - Run exactly:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_get.py .llm/todo.md
   ```

2. **Implement the task**
   - Think hard about the plan
   - Focus ONLY on implementing this specific task
   - Ignore TODO/TASK comments in source code
   - Work through the implementation methodically
   - Run appropriate tests and validation

3. **Complete the workflow**
   - Verify the build passes using the `build:precommit-runner` agent
   - Commit to git using the `git:commit-handler` agent
   - Rebase on top of the upstream branch with the `git:rebaser` agent

4. **Mark the task complete** - Run exactly:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_complete.py .llm/todo.md
   ```
