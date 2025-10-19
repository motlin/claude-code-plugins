🔁 Process all todos automatically

Repeatedly work through incomplete tasks from the project todo list.

If the user provided additional instructions, they will appear here:

<instructions>
$ARGUMENTS
</instructions>

If the user did not provide instructions, then we are working through ALL incomplete tasks, until NONE remain.

## Steps

- Track attempt count and previously attempted tasks to prevent infinite loops
- Find whether there is an incomplete task
  - Use the `@markdown-tasks` skill to extract the first incomplete task from `.llm/todo.md`
  - It returns the first `Not started` task
- If a task is found:
  - Check if we've already attempted this task 2 times
  - If yes, mark it as blocked (with `- [!]`) and continue to next task
  - If no, launch the `do-todo` agent to implement it
- Repeat until no incomplete tasks remain or we have met the user's instructions

## Todo context

The task list is in `.llm/todo.md`. You will not use the Read tool on this file. You'll interact with it through the `@markdown-tasks` skill. The format is:

```markdown
- `[ ]` - Not started
- `[x]` - Completed
- `[>]` - In progress in a peer directory/worktree
- `[!]` - Blocked/Failed after multiple attempts
```

## Important notes

- Each task is handled completely by the `do-todo` agent before moving to the next
- Each task gets its own commit for clear history

## User feedback

Throughout the process, provide clear status updates:
- "Starting task: [task description]"
- "Task completed successfully: [task description]"
- "Task failed (attempt X/2): [task description]"
- "Skipping blocked task: [task description]"
- "All tasks completed" or "Stopping due to multiple failures"
