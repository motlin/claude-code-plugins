---
name: markdown-import-plan
description: Import a plan markdown file into .llm/todo.md as self-contained implementation tasks.
---

# Markdown Import Plan

Use the `markdown-tasks` skill for task format and script path rules.

Use the user-provided plan path when available. Otherwise, use the plan file from the current conversation if one exists. If no plan is clear, ask for the path.

Archive the plan locally before creating tasks:

- Create `.llm/plans/` if needed.
- Copy or move the plan to `.llm/plans/<yyyy-mm-dd>-<descriptive-name>.md`.
- Record the absolute path.

For each plan step, add one self-contained task:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Task description
  Read and follow step N from the plan at <absolute-path>
  Context line 1"
```

Add a verification task that checks the full plan against the implementation.

Add an archive task that moves the completed plan into `.llm/plans/done/` after verification passes.

Report how many tasks were created and where the plan was archived.
