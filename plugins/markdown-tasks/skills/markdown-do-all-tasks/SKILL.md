---
name: markdown-do-all-tasks
description: Work through all incomplete tasks in .llm/todo.md with one subagent and commit per task, continuing past blocked tasks.
---

# Markdown Do All Tasks

Use the `markdown-tasks` skill for script path rules and task semantics. Use this workflow only when live edits are permitted; leave plan mode before starting the loop.

## Keep the Leader Focused

The leader coordinates the loop and does not implement tasks. It may only:

- Extract work with `task_get.py`.
- Record a failed attempt with `task_mark.py --marker='!'`.
- Spawn and wait for one fresh subagent at a time.
- Inspect Git status and commit boundaries.
- Run the test gate against `HEAD`.
- Archive the task list with `task_archive.py`.

The leader must not read `.llm/todo.md` directly, read task-referenced source files, or edit implementation files. Each worker discovers and reads its own implementation context.

## Process One Task per Worker

Extract the first incomplete task:

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

If no task is returned, proceed to archiving. Otherwise:

- Report the task being started.
- Record the current `HEAD` commit.
- Spawn one fresh subagent for only the extracted task. Give it the task block and direct it to follow `markdown-do-one-task`; do not combine tasks or add unrelated work.
- Require the worker to implement only that task, run the finish workflow, leave exactly one new task commit, and mark the task complete with `task_mark.py` only after validation succeeds.
- Wait for the worker before starting another task. Never run workers concurrently because they share the first incomplete task and Git worktree.

## Handle the Worker Result

After the worker returns:

- Require a clean worktree. Stop and report if the worker left staged or unstaged changes.
- On success, verify that `HEAD` advanced by exactly one commit and that `task_get.py` no longer returns the completed task.
- On failure, verify that `HEAD` did not advance, then mark the first incomplete task blocked so the loop can continue:

    ```bash
    python <plugin-root>/scripts/task_mark.py .llm/todo.md --marker='!'
    ```

- If the worker made commits before failing or the task state is ambiguous, stop instead of marking or stacking more work.

Blocked `[!]` tasks are skipped by `task_get.py`, so each failed task is attempted once and cannot create an infinite loop.

## Gate the Next Task on HEAD

Before extracting another task, run the repository's precommit test against the committed `HEAD`:

```bash
git test run HEAD --retest --verbose --verbose
```

Also check `git test results HEAD` when available. Continue only when the command succeeds and the recorded result is good. Stop if the result is bad or unknown; never stack another task on an unverified commit.

Repeat extraction, delegation, result handling, and the `HEAD` gate until no incomplete tasks remain.

## Archive the Finished List

When `task_get.py` returns no result, every task is completed `[x]` or blocked `[!]`. Archive the list:

```bash
python <plugin-root>/scripts/task_archive.py .llm/todo.md
```

Report the archive path and identify blocked tasks reported during this run. Do not archive early when user-supplied stopping instructions leave incomplete `[ ]` tasks.
