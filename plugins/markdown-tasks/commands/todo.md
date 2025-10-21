✅ Find and implement the next incomplete task from the project todo list.

## Steps

- Find the next incomplete task
  - Use the `@markdown-tasks` skill to extract the first incomplete task from `.llm/todo.md`
  - It returns the first `Not started` task with all its context

- Launch the `@markdown-tasks:do-todo` agent to implement the task
  - The agent handles the complete workflow: implementation, build pipeline, commit, and marking complete
  - Do NOT mark the task as complete yourself - the agent does this

- After the agent returns, you may check if more tasks remain by reading the task list again

## Todo context
The task list is in `.llm/todo.md`. You will not use the Read tool on this file. You'll interact with it through the `@markdown-tasks` skill. The format is:

```markdown
- `[ ]` - Not started
- `[x]` - Completed
- `[>]` - In progress in a peer directory/worktree
```

