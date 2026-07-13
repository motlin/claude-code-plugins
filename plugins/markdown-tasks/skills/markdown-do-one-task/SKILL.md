---
name: markdown-do-one-task
description: Find and implement the next incomplete task from .llm/todo.md.
---

# Markdown Do One Task

Use the `markdown-tasks` skill for script path rules and task semantics.

Extract the next task:

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

If no task is returned, report that there are no incomplete tasks.

Implement only the extracted task. Ignore unrelated TODO/TASK comments in source code.

Run appropriate tests and validation. Complete the repository's finish workflow so the task has its own commit, precommit passes against that commit, and the branch is rebased when required. If the `build`, `git`, and `orchestration` plugins are installed, use their `precommit`, `git-commit`, `git-rebase`, and `finish` skills.

Mark the task complete only after implementation, commit, and validation succeed:

```bash
python <plugin-root>/scripts/task_mark.py .llm/todo.md
```

If implementation or validation fails, leave the task incomplete and report the failure. The `markdown-do-all-tasks` leader is responsible for marking failed attempts `[!]`.
