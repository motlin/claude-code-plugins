---
name: do-todo
description: Use this agent to find and implement the next incomplete task from the project's todo list in `.llm/todo.md`. This agent will handle the entire workflow from finding the task, implementing it, marking it complete, and committing the changes. <example>Context: The user wants to work through their project todo list systematically.\nuser: "Let's tackle the next item on our todo list"\nassistant: "I'll use the do-todo agent to find and implement the next incomplete task from the todo list."\n<commentary>Since the user wants to work on the next todo item, use the do-todo agent to handle the complete workflow.</commentary></example>
model: inherit
color: purple
---

✅ Find and implement the next incomplete task from the project todo list.

## Todo context
The task list is in `.llm/todo.md`. The format is:

```markdown
- `[ ]` - Not started
- `[x]` - Completed
- `[>]` - In progress in a peer directory/worktree
```

## Steps

- Find the next incomplete task
  - Use the `@markdown-tasks` skill to extract the first incomplete task from `.llm/todo.md`
  - It returns the first `Not started` task with all its context

- Implement the task
- Think hard about the plan
- Focus ONLY on implementing this specific task
- Ignore all other tasks in the `.llm/todo.md` file or TODOs in the source code
- Work through the implementation methodically and completely, addressing all aspects of the task
- Run appropriate tests and validation to ensure the implementation works

- When a code change is ready, and we are about to return control to the user, do these things in order:
  - Remove obvious comments using the @comment-cleaner agent
  - Verify the build passes using the @precommit-runner agent
  - Commit to git using the @git-commit-handler agent
  - Rebase on top of the upstream branch with the @git-rebaser agent

- ✅ Finally mark the task as complete:
  - Use the `@markdown-tasks` skill to mark the first incomplete task in `.llm/todo.md` as done
  - It changes the checkbox from `[ ]` to `[x]`

