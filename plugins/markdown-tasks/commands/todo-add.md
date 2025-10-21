➕ Add a todo to the project task list.

Takes the user's description and adds it to `.llm/todo.md` as an incomplete task.

If the user provided a description, it will appear here:

<description>
$ARGUMENTS
</description>

## Steps

- Extract the description from the user's input
- If no description was provided, ask the user for one
- Add the todo using the `@markdown-tasks` skill:
  ```bash
  python3 scripts/todo_add.py $(git rev-parse --show-toplevel)/.llm/todo.md "<description>"
  ```
- The script will:
  - Create `.llm/` directory if it doesn't exist
  - Create `todo.md` file if it doesn't exist
  - Append the new todo with `[ ]` checkbox
- Confirm to the user that the todo was added

## Todo context

The task list is in `.llm/todo.md`. The format is:

```markdown
- `[ ]` - Not started
- `[x]` - Completed
- `[>]` - In progress in a peer directory/worktree
```

## Important notes

- The description should be clear and actionable
- Don't include the checkbox syntax in the description (the script adds it)
- The `.llm/` directory is gitignored via `.git/info/exclude`
