---
description: Find and implement the next incomplete task from the project task list
---

Find and implement the next incomplete task from the project task list.

## Task Implementation Workflow

### Steps

1. **Extract the task** - Run:

    ```bash
    python ${CLAUDE_PLUGIN_ROOT}/scripts/task_get.py .llm/todo.md
    ```

2. **Implement the task**
    - Think hard about the plan
    - Focus ONLY on implementing this specific task
    - Ignore TODO/TASK comments in source code
    - Work through the implementation methodically
    - Run appropriate tests and validation

3. **Complete the workflow** — Run `/orchestration:finish` to execute the full completion pipeline (commit, then precommit, rebase, and simplify). It commits before running `git test run HEAD`, which refuses to run on a dirty tree.

4. **Mark the task complete** - Run:

    ```bash
    python ${CLAUDE_PLUGIN_ROOT}/scripts/task_mark.py .llm/todo.md
    ```
