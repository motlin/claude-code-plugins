---
name: Markdown Tasks
description: Work with markdown-based task lists in .llm/todo.md files. Use when managing tasks, working with todo lists, extracting incomplete tasks, marking tasks complete, or implementing tasks from a task list.
---

# Markdown Task Management

This skill enables working with markdown task lists stored in `.llm/todo.md` at the repository root.

## Task Format

Tasks use markdown checkboxes with different states:

- `[ ]` - Not started (ready to work on)
- `[x]` - Completed and committed
- `[>]` - In progress (being worked on in a worktree)
- `[!]` - Blocked after failed attempts

Each task includes indented context lines with full implementation details:
- Absolute file paths
- Exact function/class names
- Code analogies to existing patterns
- Dependencies and prerequisites
- Expected outcomes

## Extracting the Next Task

To get the first incomplete task:

```bash
python3 scripts/todo_get.py $(git rev-parse --show-toplevel)/.llm/todo.md
```

This returns:
- The first `[ ]` checkbox line
- All indented context lines below it
- Stops at the next checkbox, header, or non-indented content

## Adding Tasks

To add a new todo to the list:

```bash
python3 scripts/todo_add.py $(git rev-parse --show-toplevel)/.llm/todo.md "Task description"
```

This creates the `.llm/` directory and `todo.md` file if they don't exist, and appends the new task with a `[ ]` checkbox.

## Marking Tasks Complete

After implementing a task, mark it as done:

```bash
python3 scripts/todo_complete.py $(git rev-parse --show-toplevel)/.llm/todo.md
```

This changes the first `[ ]` to `[x]`.

To mark a task as in-progress (for worktrees):

```bash
python3 scripts/todo_complete.py $(git rev-parse --show-toplevel)/.llm/todo.md --progress
```

This changes the first `[ ]` to `[>]`.

## Workflow Guidelines

### When Implementing a Task

1. Extract the task using `todo_get.py`
2. Read the task description and all indented context
3. Implement exactly what the task specifies
4. Focus ONLY on this specific task
5. Ignore other tasks in the file
6. Ignore TODO comments in source code
7. Run tests and validation
8. Mark complete using `todo_complete.py`

### When Planning Tasks

Create tasks that are:
- Independently readable without external context
- Self-contained with full implementation details
- Specific about file paths and function names
- Clear about expected outcomes
- Properly indented for context preservation

### Task List Location

The task list is always at:
```
<repository-root>/.llm/todo.md
```

The `.llm/` directory is gitignored via `.git/info/exclude`.

## Examples

### Example: Extract Task

```bash
$ python3 scripts/todo_get.py .llm/todo.md
- [ ] Add authentication middleware to API routes
  - File: `src/routes/api.ts`
  - Add middleware similar to `src/middleware/auth.ts`
  - Implement JWT validation
  - Return 401 for invalid tokens
```

### Example: Mark Complete

```bash
$ python3 scripts/todo_complete.py .llm/todo.md
- [x] Add authentication middleware to API routes
  - File: `src/routes/api.ts`
  - Add middleware similar to `src/middleware/auth.ts`
  - Implement JWT validation
  - Return 401 for invalid tokens
```

### Example: Mark In-Progress

```bash
$ python3 scripts/todo_complete.py .llm/todo.md --progress
- [>] Add authentication middleware to API routes
  - File: `src/routes/api.ts`
  - Add middleware similar to `src/middleware/auth.ts`
  - Implement JWT validation
  - Return 401 for invalid tokens
```

## Script Details

### todo_add.py

**Purpose**: Add a new task to the todo list

**Input**:
- Path to todo.md file
- Task description

**Output**: The added task line

**Exit codes**:
- 0: Success
- 1: Error

**Behavior**:
- Creates `.llm/` directory if it doesn't exist
- Creates `todo.md` file if it doesn't exist
- Appends task with `[ ]` checkbox

### todo_get.py

**Purpose**: Extract first incomplete task with context

**Input**: Path to todo.md file

**Output**: Task line and all indented context lines

**Exit codes**:
- 0: Success
- 1: File not found or error

### todo_complete.py

**Purpose**: Mark first incomplete task as done or in-progress

**Input**:
- Path to todo.md file
- Optional: `--progress` flag for in-progress marking
- Optional: `--done` flag for explicit completion (default)

**Output**: The marked task with context

**Exit codes**:
- 0: Success
- 1: No incomplete tasks found or error

## Dependencies

These scripts require Python 3 with standard library only (no external packages needed).
