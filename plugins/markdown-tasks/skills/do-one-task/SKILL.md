---
name: do-one-task
description: Find and implement the next incomplete task from .llm/todo.md, commit it through the finish workflow, and mark it done. Use when the user wants the next queued task done.
---

# Do One Task

Use the `markdown-tasks:tasks` skill for script path rules and task semantics. `<plugin-root>` is `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, it is the plugin root that contains this `skills/do-one-task/SKILL.md` file.

Extract the next task:

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

If no task is returned, report that there are no incomplete tasks.

Implement only the extracted task. Ignore unrelated TODO/TASK comments in source code.

Run appropriate tests and validation, then complete the repository's finish workflow so the task has its own commit, precommit passes against that commit, and the branch is rebased when required. When the build, git, and orchestration plugins are installed, use the `build:precommit`, `git:commit`, `git:git-rebase`, and `orchestration:finish` skills; in Claude Code, `/orchestration:finish` runs the full pipeline. Commit before running `git test run HEAD`, which refuses a dirty tree.

The task must end as exactly one new commit. Finish can leave a cleanup `fixup!` commit on top of the task commit, so after it returns, check the commits between the rebase target (`${UPSTREAM_REMOTE:-upstream}/${UPSTREAM_BRANCH:-main}`) and `HEAD` for `fixup!` commits and fold any into the task commit with the `git:git-rebase` skill, which autosquashes. Run precommit again if the squash changed `HEAD`.

Mark the task complete only after implementation, commit, and validation succeed:

```bash
python <plugin-root>/scripts/task_mark.py .llm/todo.md
```

If implementation or validation fails, leave the task incomplete and report the failure. The `markdown-tasks:do-all-tasks` leader marks failed attempts `[!]`.
