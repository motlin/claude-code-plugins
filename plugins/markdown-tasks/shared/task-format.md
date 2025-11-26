# Task Format Reference

The task list is in `.llm/todo.md`.

**NEVER use the `Read` tool on `.llm/todo.md`**.

Always interact with the task list exclusively through the `@tasks` skill using the Python scripts it provides.

## Task States

Tasks use markdown checkboxes with different states:

- `[ ]` - Not started (ready to work on)
- `[x]` - Completed
- `[!]` - Blocked after failed attempt

## Task Structure

Each task includes indented context lines with full implementation details:

- Absolute file paths
- Exact function/class names
- Code analogies to existing patterns
- Dependencies and prerequisites
- Expected outcomes

## Example Task

```markdown
- [ ] Add authentication middleware to API routes
  - File: `src/routes/api.ts`
  - Add middleware similar to `src/middleware/auth.ts`
  - Implement JWT validation
  - Return 401 for invalid tokens
```

## Task List Location

The task list is always at:

```
<repository-root>/.llm/todo.md
```

The `.llm/` directory is gitignored via `.git/info/exclude`.

## Planning Guidelines

Create tasks that are:

- Independently readable without external context
- Self-contained with full implementation details
- Specific about file paths and function names
- Clear about expected outcomes
- Properly indented for context preservation

Since each task is read independently using `task_get.py`, any context that is relevant to multiple tasks MUST be repeated in each task's indented context. Do not rely on tasks reading shared context from elsewhere in the file.

For example, if multiple tasks need to know about a specific API pattern:

```markdown
- [ ] Implement user endpoint
  - API pattern: Use `BaseController` class from `src/controllers/base.ts`
  - File: `src/controllers/user.ts`

- [ ] Implement post endpoint
  - API pattern: Use `BaseController` class from `src/controllers/base.ts`
  - File: `src/controllers/post.ts`
```

Each task contains the shared API pattern context because `task_get.py` only extracts one task at a time.
