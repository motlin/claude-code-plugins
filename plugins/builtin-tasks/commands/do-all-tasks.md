---
argument-hint: optional instructions
description: Process all tasks automatically using built-in task management
---

Process all tasks automatically using Claude Code's built-in task tools.

Repeatedly work through incomplete tasks from the built-in task list.

If the user provided additional instructions, they will appear here:

<instructions>
$ARGUMENTS
</instructions>

If the user did not provide instructions, work through ALL incomplete tasks until NONE remain.

## Steps

1. Track attempt count and previously attempted tasks to prevent infinite loops
2. Call `TaskList` to find the first pending, unblocked task
3. If a task is found:
   - Check if we have already attempted this task 1 time
   - If yes, skip it and continue to the next task
   - If no, launch the `builtin-tasks:do-task` agent to implement it
   - **Do NOT add instructions to the agent prompt** — the agent is self-contained and follows its own workflow (including precommit, commit, rebase)
   - Do NOT mark the task as complete yourself — the `do-task` agent does this
4. Repeat until no incomplete tasks remain or the user's instructions are met
5. When all tasks are completed, report the final status

## Notes

- Each task is handled completely by the `do-task` agent before moving to the next
- The `do-task` agent marks tasks as complete — do NOT call `TaskUpdate` yourself
- Each task gets its own commit for clear history
- After each agent returns, call `TaskList` again to see if more tasks remain

## User feedback

Throughout the process, provide clear status updates:

- "Starting task: [task subject]"
- "Task completed successfully: [task subject]"
- "Task failed: [task subject]"
- "Skipping previously failed task: [task subject]"
- "All tasks completed" or "Stopping due to failures"
