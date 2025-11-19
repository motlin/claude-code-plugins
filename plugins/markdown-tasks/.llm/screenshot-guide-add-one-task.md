# Screenshot Guide: /add-one-task Command

This guide helps you capture screenshots demonstrating the `/add-one-task` command functionality.

## What to Capture

### 1. Basic Single Task Addition

**Screenshot 1: Command Input**
- Run the command: `/add-one-task Implement user authentication`
- Capture the terminal/UI showing the command being entered
- Ensure the command and description are clearly visible

**Screenshot 2: Claude's Response**
- Capture Claude's confirmation message
- Should show acknowledgment that the task was added to `.llm/todo.md`
- Include any output from the `task_add.py` script

**Screenshot 3: Resulting Entry in todo.md**
- Open `.llm/todo.md` in your editor
- Show the newly added task with `[ ]` checkbox
- Highlight or focus on the new entry
- Example expected content:
  ```markdown
  - [ ] Implement user authentication
  ```

### 2. Multi-line Task with Context

**Screenshot 4: Multi-line Command**
- Demonstrate adding a task with detailed context
- Run a command like:
  ```
  /add-one-task Fix authentication bug in login flow
  ```
- Then ask Claude to add context lines, or demonstrate the natural flow where Claude adds context
- Alternative: Show editing `.llm/todo.md` to add indented context lines manually
- Expected result in todo.md:
  ```markdown
  - [ ] Fix authentication bug in login flow
    - File: `src/auth/login.ts`
    - Issue: JWT validation fails for refresh tokens
    - Fix: Update token validation logic in validateToken()
    - Expected: Refresh tokens should validate successfully
  ```

### 3. Building Up a Task List

**Screenshot 5: Multiple Sequential Additions**
- Run `/add-one-task` three or more times with different tasks
- Show the progression:
  ```
  /add-one-task Implement user dashboard
  /add-one-task Add dark mode toggle
  /add-one-task Create settings page
  ```
- Capture the final state of `.llm/todo.md` showing all tasks:
  ```markdown
  - [ ] Implement user dashboard
  - [ ] Add dark mode toggle
  - [ ] Create settings page
  ```

## Screenshot Organization

Save screenshots with descriptive names:
- `add-one-task-01-command-input.png`
- `add-one-task-02-claude-response.png`
- `add-one-task-03-todo-result.png`
- `add-one-task-04-multiline-context.png`
- `add-one-task-05-multiple-tasks.png`

## Tips for Good Screenshots

1. **Use a clean environment**: Start with no existing `.llm/todo.md` file to show the creation flow
2. **Clear terminal**: Clear your terminal before each screenshot for clarity
3. **Readable font size**: Ensure text is large enough to read
4. **Full context**: Include enough surrounding UI to show the environment (terminal, editor, etc.)
5. **Highlight key elements**: Circle or highlight important parts if needed
6. **Show file paths**: Include file paths in screenshots to show where `.llm/todo.md` is located

## Documentation Goals

The screenshots should demonstrate:
- How simple it is to add a single task
- That tasks are stored in `.llm/todo.md` with checkbox syntax
- How to build up a task list incrementally
- The natural workflow of adding tasks during planning/discussion
- That context can be added through conversation or manual editing

## Before Starting

1. Navigate to a test project directory
2. Ensure `.llm/todo.md` doesn't exist (or delete it)
3. Start a fresh Claude Code session
4. Have your screenshot tool ready (macOS: Cmd+Shift+4, Windows: Snipping Tool, Linux: gnome-screenshot)
