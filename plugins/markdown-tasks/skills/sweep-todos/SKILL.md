---
name: sweep-todos
description: Find TODO comments in the codebase and add each one to .llm/todo.md as a task. Use when the user wants source TODOs collected into the task list.
---

# Sweep TODOs

Find all TODO comments and add them to the project task list. Each TODO found in the code becomes a task in `.llm/todo.md`.

Use the `markdown-tasks:tasks` skill for task format and script path rules.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/sweep-todos/SKILL.md` file.

Search the codebase for every occurrence of "TODO" using grep/search. For each occurrence, capture:

- File path.
- Line number.
- Full TODO text with comment markers (`//`, `#`, `/* */`) removed.

Compose all TODO tasks before writing. Add the complete batch in one shell command by chaining one call per TODO with `&&`:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Implement TODO from src/api/client.ts:87: Extract commonality in getRootNodes and getChildNodes" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Implement TODO from test/utils.test.ts:103: Use deep object equality rather than loose assertions"
```

Never add a multi-TODO batch across separate shell commands. Keeping the writes together keeps the write window to `.llm/todo.md` extremely short, so concurrent sessions are far less likely to interleave their tasks.

Report how many TODO tasks were added.
