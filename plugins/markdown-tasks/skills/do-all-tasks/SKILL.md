---
name: do-all-tasks
description: Work through every incomplete task in .llm/todo.md with one fresh do-task agent and one commit per task, skipping blocked tasks. Use when the user wants the whole task list processed automatically.
---

# Do All Tasks

Work through incomplete tasks in `.llm/todo.md`, one fresh worker and one commit per task.

Use the `markdown-tasks:tasks` skill for script path rules and task semantics. `<plugin-root>` is `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, it is the plugin root that contains this `skills/do-all-tasks/SKILL.md` file.

Instructions the user gave after the skill name govern how far the loop runs and any constraints on it. Without instructions, run until no incomplete tasks remain.

## Leave Plan Mode First

Workers make live edits, so this workflow cannot run in plan mode. If plan mode is active in Claude Code, call `ExitPlanMode` before doing anything else.

## Check Delegation Before Starting

Before running any queue script, confirm the session exposes callable tools to spawn a fresh subagent and wait for its result. In Codex, check the available tool set rather than assuming delegation is supported.

If either capability is missing, stop. Report which one is unavailable and that this workflow needs both. Leave task states, archives, and Git unchanged, and do not mark tasks blocked for this reason. Implementing tasks directly in the leader is not a fallback.

## Keep the Leader Focused

The leader (this agent) coordinates and never implements. It uses only Bash and the agent-spawning tool, never Read, Edit, Write, Grep, or Glob. With Bash it may only:

- Extract work with `task_get.py`.
- Survey blocked work with `task_unblock.py --dry-run`.
- Record a failed attempt with `task_mark.py --marker='!' --reason='<what failed>'`.
- Inspect Git status and commit boundaries.
- Run the test gate against `HEAD`.
- Archive the task list with `task_archive.py`.

`task_get.py` is the leader's only view of the queue. It never reads `.llm/todo.md`, task-referenced files, or source files. Each worker discovers its own implementation context.

## Report Blocked Work Before the Loop

Blocked `[!]` tasks from earlier runs are invisible to `task_get.py`, so survey them first:

```bash
python <plugin-root>/scripts/task_unblock.py .llm --dry-run
```

The dry run rewrites nothing. Its per-file counts show the blocked tasks in `.llm/todo.md` that this run will skip and the blocked work still waiting in archives.

Report those counts before spawning the first worker, where they will not scroll away under the run's output, then continue. Recovery is the user's decision: point them at the `markdown-tasks:markdown-unblock-tasks` skill.

## Process One Task per Worker

Track which tasks this run has attempted.

Extract the first incomplete task:

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

If no task is returned, go to archiving. Otherwise:

- Report "Starting task: [task description]".
- If this run already attempted this task, its failure went unrecorded. Mark it blocked (see below) and extract the next task instead of retrying.
- Record the current `HEAD` commit.
- In Claude Code, launch the `markdown-tasks:do-task` agent. In Codex, spawn one fresh subagent and direct it to follow the `markdown-tasks:do-one-task` skill.
- Add no instructions to the worker prompt. The worker extracts its own task, implements only that task, runs the finish workflow, leaves exactly one commit, and marks the task complete itself.
- Wait for the worker before starting another. Never run workers concurrently; they share the task file and the Git worktree.

## Handle the Worker Result

- Require a clean worktree. Stop and report if the worker left staged or unstaged changes.
- On success, verify that `HEAD` advanced by exactly one commit and that `task_get.py` no longer returns the completed task. Report "Task completed successfully: [task description]".
- On failure, report "Task failed: [task description]", verify that `HEAD` did not advance, and mark the first incomplete task (the failed one) blocked:

    ```bash
    python <plugin-root>/scripts/task_mark.py .llm/todo.md --marker='!' --reason='<what failed>'
    ```

    The reason is the only record of the failure that survives this session. Quote the concrete failure the worker reported (the failing command, the assertion, the missing dependency), not a restatement of the task. Report "Skipping blocked task: [task description]". `task_get.py` skips `[!]` tasks, so each failing task is attempted once.

- If the worker made commits before failing, or the task state is ambiguous, stop instead of marking or stacking more work.

## Gate the Next Task on HEAD

Before extracting another task, run the precommit test against `HEAD`. It is cached, so an already-passing commit returns almost instantly:

```bash
git test run HEAD --retest --verbose --verbose
```

Also check `git test results HEAD` when available. Continue only when the command succeeds and the recorded result is good. If the result is bad or unknown, report "Stopping due to failures" and stop; never stack a task on an unverified commit.

Repeat extraction, delegation, result handling, and the gate until no incomplete tasks remain or the user's instructions are met.

## Archive the Finished List

When `task_get.py` returns nothing, every task is `[x]` or `[!]`. Archive the list:

```bash
python <plugin-root>/scripts/task_archive.py .llm/todo.md
```

Report "All tasks completed - task list archived to .llm/YYYY-MM-DD-todo.md", the number of blocked tasks carried forward, and the tasks blocked during this run. Do not archive when the user's stopping instructions leave `[ ]` tasks behind.
