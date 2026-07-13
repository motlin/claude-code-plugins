---
name: markdown-import-plan
description: Import a plan markdown file into .llm/todo.md as self-contained implementation tasks.
---

# Markdown Import Plan

Use the `markdown-tasks` skill for task format and script path rules.

Use the user-provided plan path when available. Otherwise, use the plan file from the current conversation if one exists. In Claude Code, if no plan is remembered, identify the most recently modified plan under `~/.claude/plans/` and confirm it with the user. In Codex, ask for the path when the conversation does not identify a stored plan.

Archive the plan locally before creating tasks:

- Create `.llm/plans/` if needed.
- Copy or move the plan to `.llm/plans/<yyyy-mm-dd>-<descriptive-name>.md`.
- Record the absolute path.

Compose all plan-step tasks, the verification task, and the archive task before writing. Add the complete batch in one shell command by chaining one call per task with `&&`:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Task description
  Read and follow step N from the plan at <absolute-path>
  Context line 1" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Verify the full plan implementation
  Read the entire plan at <absolute-path>" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Archive the completed plan
  Move <absolute-path> into .llm/plans/done/ only after verification succeeds"
```

Never add a multi-task import across separate shell commands. Keeping the writes together reduces the chance that concurrent sessions interleave their tasks.

Every task must contain the archived plan's absolute path and all context needed to execute it without seeing another task. Add a verification task that checks the full plan against the implementation.

Add an archive task that moves the completed plan into `.llm/plans/done/` after verification passes.

Report how many tasks were created and where the plan was archived.
