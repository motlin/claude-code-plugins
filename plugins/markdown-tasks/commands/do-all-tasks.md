🔁 Process all tasks automatically

Repeatedly work through incomplete tasks from the project task list.

If the user provided additional instructions, they will appear here:

<instructions>
$ARGUMENTS
</instructions>

If the user did not provide instructions, then we are working through ALL incomplete tasks, until NONE remain.

## Steps

- Track attempt count and previously attempted tasks to prevent infinite loops
- Find whether there is an incomplete task
  - Use the `@tasks` skill to extract the first incomplete task from `.llm/todo.md`
  - It returns the first `Not started` task
- If a task is found:
  - Check if we've already attempted this task 1 time
  - If yes, mark it as blocked (with `- [!]`) and continue to next task
  - If no, launch the `@tasks:do-task` agent to implement it
  - Do NOT mark the task as complete yourself - the `do-task` agent does this
- Repeat until no incomplete tasks remain or we have met the user's instructions
- When all tasks are completed:
  - Archive the task list using: `python3 plugins/markdown-tasks/skills/tasks/scripts/task_archive.py .llm/todo.md`
  - This moves the file to `.llm/YYYY-MM-DD-todo.md`

## Task context

The task list is in `.llm/todo.md`. Do not use the Read tool on this file. Interact with it through the `@tasks` skill. The format is:

```markdown
- `[ ]` - Not started
- `[x]` - Completed
- `[!]` - Blocked after multiple failed attempts
```

## Important notes

- Each task is handled completely by the `do-task` agent before moving to the next
- The `do-task` agent marks tasks as complete - do NOT call task_complete.py yourself
- Each task gets its own commit for clear history
- After each agent returns, check the task list again to see if more tasks remain

## User feedback

Throughout the process, provide clear status updates:
- "Starting task: [task description]"
- "Task completed successfully: [task description]"
- "Task failed: [task description]"
- "Skipping blocked task: [task description]"
- "All tasks completed - task list archived to .llm/YYYY-MM-DD-todo.md" or "Stopping due to failures"
