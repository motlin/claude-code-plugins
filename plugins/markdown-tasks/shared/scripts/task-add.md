# task_add.py - Add New Task

Add a new task to the list:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_add.py .llm/todo.md "Task description"
```

Creates the `.llm/` directory and `todo.md` file if they do not exist, and appends the new task with a `[ ]` checkbox.

**Important**: You can (and should) pass a multi-line string with all indented implementation details in a single call:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_add.py .llm/todo.md "Fix temporal table primary keys to use (id, system_to) pattern
  Problem: All temporal tables currently use (id, system_from) as PK
  Files: src/db/schema.ts, src/commands/cache/import-backup.ts
```

The script preserves all indentation in the multi-line string.

**Exit codes**: 0 (success), 1 (error)
