---
name: do-one-task
description: Find and implement the next incomplete task from .llm/todo.md, commit it through the finish workflow, and mark it done. Use when the user wants the next queued task done.
---

# Do One Task

Find and implement the next incomplete task from the project task list.

Use the `markdown-tasks:tasks` skill for script path rules and task semantics.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/do-one-task/SKILL.md` file.

Extract the next task:

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

If no task is returned, report that there are no incomplete tasks.

Think hard about the plan before changing anything. Implement only the extracted task, working through the implementation methodically. Ignore unrelated TODO/TASK comments in source code.

Run appropriate tests and validation. Complete the repository's finish workflow so the task has its own commit, precommit passes against that commit, and the branch is rebased when required. If the build, git, and orchestration plugins are installed, use the `build:precommit`, `git:commit`, `git:git-rebase`, and `orchestration:finish` skills; in Claude Code, `/orchestration:finish` runs the full completion pipeline. It commits before running `git test run HEAD`, which refuses to run on a dirty tree.

Mark the task complete only after implementation, commit, and validation succeed:

```bash
python <plugin-root>/scripts/task_mark.py .llm/todo.md
```

If implementation or validation fails, leave the task incomplete and report the failure. The `markdown-tasks:do-all-tasks` leader is responsible for marking failed attempts `[!]`.
