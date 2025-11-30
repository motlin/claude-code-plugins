# task_archive.py - Archive Task List

Archive a completed task list by running this command (do NOT read the script file):

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_archive.py .llm/todo.md
```

Moves the file to `.llm/YYYY-MM-DD-todo.md` where YYYY-MM-DD is today's date. If a file with that name already exists, a counter suffix is added (e.g., `YYYY-MM-DD-todo-1.md`).

**Exit codes**: 0 (success), 1 (file not found or error)
