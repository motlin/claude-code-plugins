# task_complete.py - Mark Task Done

Mark the first incomplete task as done:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_complete.py .llm/todo.md
```

Changes the first `[ ]` to `[x]`.

**Exit codes**: 0 (success), 1 (no incomplete tasks or error)
