---
name: do-all-tasks
description: Work through every incomplete task in .llm/todo.md with one fresh do-task agent and one commit per task, skipping blocked tasks. Use when the user wants the whole task list processed automatically.
---

# Do All Tasks

Process all tasks automatically. Repeatedly work through incomplete tasks from the project task list, one worker per task.

Use the `markdown-tasks:tasks` skill for script path rules and task semantics.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/do-all-tasks/SKILL.md` file.

If the user gave instructions after the skill name, they govern how far the loop runs and any constraints on the run. If the user did not provide instructions, work through ALL incomplete tasks until NONE remain.

## Leave Plan Mode First

This workflow drives live edits through worker agents and must not run in plan mode. If plan mode is active, call `ExitPlanMode` in Claude Code before doing anything else. Do not begin the loop until edits are permitted.

## Check Delegation Before Starting

Before running queue scripts, check that the current session exposes callable tools to spawn a fresh subagent and wait for its result. In Codex, check the available tool set rather than assuming delegation is supported. When both capabilities are available, continue with the leader workflow below.

If either capability is missing, stop before entering the loop. Report which capability is unavailable and that this workflow requires a session with subagent spawning and result retrieval. Leave task states, archives, and Git unchanged; do not mark tasks blocked because the session lacks delegation tools. Resume this skill in a session with those tools. Direct implementation by the leader is not a fallback for this workflow.

## Keep the Leader Focused

The leader (this agent) coordinates the loop and does not implement tasks. It uses ONLY two kinds of tools: Bash, for the `task_*` scripts and the Git commands below, and the agent-spawning tool. It must not use Read, Edit, Write, Grep, or Glob at any point in the run. The leader may only:

- Extract work with `task_get.py`.
- Survey blocked work with `task_unblock.py --dry-run`.
- Record a failed attempt with `task_mark.py --marker='!' --reason='<what failed>'`.
- Spawn and wait for one fresh worker agent at a time.
- Inspect Git status and commit boundaries.
- Run the test gate against `HEAD`.
- Archive the task list with `task_archive.py`.

The leader never reads `.llm/todo.md` directly; `task_get.py` hands it exactly one task, and that is the only view of the queue it needs. It never reads task-referenced files or source files, and it never writes or edits anything except through the scripts above and the worker agent. Blocking a task needs no editing either, because `task_mark.py --marker='!'` does it. Each worker discovers and reads its own implementation context.

## Report Blocked Work Before the Loop

Blocked `[!]` tasks left by an earlier run are invisible to `task_get.py`, so open the run by surveying them:

```bash
python <plugin-root>/scripts/task_unblock.py .llm --dry-run
```

The dry run rewrites nothing. It reports the blocked count per file, so `.llm/todo.md` shows the blocked tasks this run will skip and the archives show blocked work still waiting for recovery.

Report those counts to the user before spawning the first worker, not after the loop finishes, where they scroll away under the run's output. Blocked tasks in `.llm/todo.md` are skipped rather than retried, so state the count and continue. Recovering them is the user's decision, not something the loop makes on its own; point them at the `markdown-tasks:markdown-unblock-tasks` skill and move on.

## Process One Task per Worker

Track the attempt count and the tasks already attempted so a repeatedly failing task cannot create an infinite loop.

Extract the first incomplete task:

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

If no task is returned, proceed to archiving. Otherwise:

- Report "Starting task: [task description]".
- If this task was already attempted once in this run, its failure went unrecorded; mark it blocked with `task_mark.py --marker='!' --reason='<what failed>'` (see below) and extract the next task instead of retrying.
- Record the current `HEAD` commit.
- In Claude Code, launch the `markdown-tasks:do-task` agent. In Codex, spawn one fresh subagent and direct it to follow the `markdown-tasks:do-one-task` skill. Either way the worker handles only the first incomplete task; do not combine tasks or add unrelated work.
- Do NOT add instructions to the agent prompt. The worker is self-contained: it extracts its own task with `task_get.py`, implements only that task, runs the finish workflow (precommit, commit, rebase), leaves exactly one new task commit, and marks the task complete with `task_mark.py` only after validation succeeds.
- Do NOT mark the task as complete yourself; the worker does this.
- Wait for the worker before starting another task. Never run workers concurrently because they share the first incomplete task and Git worktree.

## Handle the Worker Result

After the worker returns:

- Require a clean worktree. Stop and report if the worker left staged or unstaged changes.
- On success, verify that `HEAD` advanced by exactly one commit and that `task_get.py` no longer returns the completed task. Report "Task completed successfully: [task description]".
- On failure, report "Task failed: [task description]", verify that `HEAD` did not advance, then mark the first incomplete task blocked so the loop can continue:

    ```bash
    python <plugin-root>/scripts/task_mark.py .llm/todo.md --marker='!' --reason='<what failed>'
    ```

    The failed task is always the first incomplete task, so this targets it, and `task_get.py` skips `[!]` on the next iteration. `--reason` is required here and is recorded in the task body, so it is the only record of the failure that survives this session. Quote the concrete failure the worker reported — the failing command, the assertion, the missing dependency — not a restatement of the task. The script rejects a blocked mark with no reason. Report "Skipping blocked task: [task description]" when moving past it.

- If the worker made commits before failing or the task state is ambiguous, stop instead of marking or stacking more work.

Blocked `[!]` tasks are skipped by `task_get.py`, so each failed task is attempted once and cannot create an infinite loop.

## Gate the Next Task on HEAD

Before extracting another task, run the repository's precommit test against the committed `HEAD`. It is cached, so it returns near-instantly on an already-passing commit:

```bash
git test run HEAD --retest --verbose --verbose
```

Also check `git test results HEAD` when available. Continue only when the command succeeds and the recorded result is good. Stop the loop and report if the result is bad or unknown; never stack another task on an unverified commit.

Repeat extraction, delegation, result handling, and the `HEAD` gate until no incomplete tasks remain or the user's instructions are met. Each task is handled completely by its worker before the next one starts, and gets its own commit for clear history. After each worker returns, run `task_get.py` again to determine whether any work remains.

## Archive the Finished List

When `task_get.py` returns no result, every task is completed `[x]` or blocked `[!]`. Archive the list:

```bash
python <plugin-root>/scripts/task_archive.py .llm/todo.md
```

Archiving carries blocked `[!]` tasks forward into a fresh `.llm/todo.md` instead of filing them away, and reports how many it carried. Report the archive path and that carried-forward count alongside the blocked tasks seen during this run. Do not archive early when user-supplied stopping instructions leave incomplete `[ ]` tasks.

## User Feedback

Throughout the process, provide clear status updates using these exact strings:

- "Starting task: [task description]"
- "Task completed successfully: [task description]"
- "Task failed: [task description]"
- "Skipping blocked task: [task description]"
- "All tasks completed - task list archived to .llm/YYYY-MM-DD-todo.md" or "Stopping due to failures"
