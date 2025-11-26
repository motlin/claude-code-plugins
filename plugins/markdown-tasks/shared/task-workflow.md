✅ Find and implement the next incomplete task from the project task list.

## Task context

The task list is in `.llm/todo.md`.

**NEVER use the `Read` tool on `.llm/todo.md`**.

Always interact with the task list exclusively through the `@tasks` skill using the Python scripts described below.

The task format is:

```markdown
- `[ ]` - Not started
- `[x]` - Completed
- `[!]` - Blocked after failed attempt
```

## Steps

- Find the next incomplete task
  - Use the [task_get.py](${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_get.py) script to extract the first incomplete task from `.llm/todo.md`
  - The script returns the first `Not started` task with all its context

- Implement the task
- Think hard about the plan
- Focus ONLY on implementing this specific task
- Ignore TODO/TASK comments in the source code
- Work through the implementation methodically and completely, addressing all aspects of the task
- Run appropriate tests and validation to ensure the implementation works

- When a code change is ready, and we are about to return control to the user, do these things in order:
  - Verify the build passes using the `@build:precommit-runner` agent
  - Commit to git using the `@git:commit-handler` agent
  - Rebase on top of the upstream branch with the `@git:rebaser` agent

- ✅ Finally mark the task as complete:
  - Use the [task_complete.py](${CLAUDE_PLUGIN_ROOT}/skills/tasks/scripts/task_complete.py) script to mark the first incomplete task in `.llm/todo.md` as done
  - It changes the checkbox from `[ ]` to `[x]`
