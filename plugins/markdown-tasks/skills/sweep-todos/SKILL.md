---
name: sweep-todos
description: Find TODO comments in the codebase and add each one to .llm/todo.md as a task. Use when the user wants source TODOs collected into the task list.
---

# Sweep TODOs

Turn every `TODO` comment in the codebase into a task in `.llm/todo.md`.

Use the `markdown-tasks:tasks` skill for task format and script path rules. `<plugin-root>` is `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, it is the plugin root that contains this `skills/sweep-todos/SKILL.md` file.

Search the codebase for every `TODO` and capture its file path, line number, and full text with comment markers (`//`, `#`, `/* */`) removed.

Compose all tasks first, then add the batch in one shell command, chaining one call per TODO with `&&` so concurrent sessions are unlikely to interleave their tasks:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Implement TODO from src/api/client.ts:87: Extract commonality in getRootNodes and getChildNodes" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Implement TODO from test/utils.test.ts:103: Use deep object equality rather than loose assertions"
```

Report how many TODO tasks were added.
