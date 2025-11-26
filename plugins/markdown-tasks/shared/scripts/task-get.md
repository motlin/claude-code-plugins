# task_get.py - Extract Next Task

Extract the first incomplete task with its context:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_get.py .llm/todo.md
```

Returns:

- The first `[ ]` checkbox line
- All indented context lines below it
- Stops at the next checkbox, header, or non-indented content

**Exit codes**: 0 (success), 1 (file not found or error)
