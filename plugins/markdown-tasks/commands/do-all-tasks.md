---
argument-hint: optional instructions
description: Process all tasks automatically
disallowed-tools: Read, Edit, Write, Grep, Glob
---

Process all tasks automatically.

Repeatedly work through incomplete tasks from the project task list.

If the user provided additional instructions, they will appear here:

<instructions>
$ARGUMENTS
</instructions>

If the user did not provide instructions, work through ALL incomplete tasks until NONE remain.

## Steps

1. **Plan-mode guard.** This command drives live edits through the `do-task` subagent and must not run in plan mode. If plan mode is active, call `ExitPlanMode` before doing anything else. Do not begin the loop until edits are permitted.
2. **Leader discipline.** The leader (this agent) only discovers work via `task_get.py` and records failures via `task_mark.py`. It never reads `todo.md`, task-referenced files, or source files directly, and it never writes or edits anything except through those two scripts and the `do-task` subagent. The `do-task` agent reads everything itself.
3. Track attempt count and previously attempted tasks to prevent infinite loops.
4. Extract the first incomplete task from `.llm/todo.md`:

    ```bash
    python ${CLAUDE_PLUGIN_ROOT}/scripts/task_get.py .llm/todo.md
    ```

5. If a task is found:
    - Check whether we have already attempted this task once
    - If yes, mark it blocked and continue to the next task: `python ${CLAUDE_PLUGIN_ROOT}/scripts/task_mark.py .llm/todo.md --marker='!'` (the blocked task is always the first incomplete task, so this targets it; `task_get.py` skips `[!]` on the next iteration)
    - If no, launch the `markdown-tasks:do-task` agent to implement it
    - **Do NOT add instructions to the agent prompt** - the agent is self-contained and follows its own workflow (including precommit, commit, rebase)
    - Do NOT mark the task as complete yourself - the `do-task` agent does this
6. Repeat until no incomplete tasks remain or the user's instructions are met
7. When `task_get.py` returns no result (every item is marked done `[x]`, blocked `[!]`, or skipped), archive the task list:

    ```bash
    python ${CLAUDE_PLUGIN_ROOT}/scripts/task_archive.py .llm/todo.md
    ```

## Notes

- Each task is handled completely by the `do-task` agent before moving to the next, and gets its own commit for clear history
- The `do-task` agent marks tasks done (`[x]`). The leader's only write action is marking a failed task blocked via `task_mark.py --marker='!'`
- After each agent returns, run `task_get.py` again to determine whether any work remains

## User feedback

Throughout the process, provide clear status updates:

- "Starting task: [task description]"
- "Task completed successfully: [task description]"
- "Task failed: [task description]"
- "Skipping blocked task: [task description]"
- "All tasks completed - task list archived to .llm/YYYY-MM-DD-todo.md" or "Stopping due to failures"
