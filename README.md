# Claude Code Plugins

Collection of Claude Code plugins for task management, workflow automation, and productivity.

## Plugins

### Markdown Tasks

Task management system for Claude Code using markdown checkboxes in `.llm/todo.md` with slash commands for planning, implementing, and tracking tasks across git worktrees.

## Features

- 📝 Markdown-based task tracking in `.llm/todo.md`
- ✅ Visual checkbox system for task states (`[ ]`, `[x]`, `[>]`, `[!]`)
- 🤖 Automated task implementation with the `do-todo` agent
- 🌳 Parallel task execution using git worktrees
- 🔄 Integrated build pipeline (format, lint, test, commit)
- 🎯 Self-contained task format with full context

## Installation

```bash
# Add the marketplace
/plugin marketplace add motlin/claude-code-plugins

# Install the markdown-tasks plugin
/plugin install markdown-tasks
```

This installs:
- 6 slash commands (`/plan`, `/split-tasks`, `/todo`, `/todo-all`, `/todo-sweep`, `/worktree`)
- 1 agent (`do-todo`)
- 1 skill (`markdown-tasks`) with bundled Python scripts

No additional setup required - the skill's scripts are automatically available when the plugin is installed.

### Verification

Check that the plugin is installed:

```bash
/plugin list
```

Check that the commands are available:

```bash
/help
```

## Task States

Tasks use markdown checkboxes with different states:

- `[ ]` - Ready to work on
- `[x]` - Completed and committed
- `[>]` - In progress (currently being worked on in a worktree)
- `[!]` - Blocked after 2 failed attempts

## Commands

### `/plan` - Create Initial Task List

Converts high-level requirements into a structured task list in `.llm/todo.md`.

```bash
/plan Implement user authentication with OAuth
```

Creates tasks with:
- Full absolute file paths
- Exact class/function/method names
- Code analogies to existing patterns
- Dependencies and prerequisites
- Expected outcomes

### `/split-tasks` - Break Down Complex Plans

Transforms discussion context into granular, self-contained tasks.

```bash
/split-tasks
```

### `/todo` - Work on Next Task

Finds and implements exactly one incomplete task with full build validation.

```bash
/todo
```

Workflow:
1. Extracts first `[ ]` task
2. Implements the task
3. Runs build pipeline (comment-cleaner, precommit-runner, git-commit-handler, git-rebaser)
4. Marks task as `[x]`

### `/todo-all` - Process All Tasks

Automatically works through all incomplete tasks sequentially.

```bash
/todo-all
```

Features:
- Tracks attempt count (max 2 attempts per task)
- Marks blocked tasks as `[!]`
- Each task gets its own commit
- Provides status updates

### `/worktree` - Parallel Task Execution

Creates git worktrees for parallel task processing.

```bash
/worktree 3  # Creates 3 worktrees for next 3 tasks
```

Workflow per task:
1. Generates kebab-case task name
2. Creates git worktree
3. Marks task as `[>]` in-progress
4. Opens new Claude Code session in worktree

### `/todo-sweep` - Harvest Code TODOs

Finds all TODO comments in codebase and adds them to `.llm/todo.md`.

```bash
/todo-sweep
```

Output format:
```markdown
- [ ] Implement TODO from src/api/client.ts:87: Extract commonality in getRootNodes and getChildNodes
```

## Agent

### `do-todo` - Complete Task Workflow

Implements a single task with full build pipeline and marks it complete.

Used internally by `/todo` and `/todo-all` commands.

## Binaries

### `todo-get`

Extracts the first incomplete task from todo.md.

```bash
todo-get $(git rev-parse --show-toplevel)/.llm/todo.md
```

Returns:
- First `[ ]` task
- All indented context lines below it
- Stops at next checkbox or header

### `todo-complete`

Marks the first incomplete task as done or in-progress.

```bash
# Mark as done (default)
todo-complete $(git rev-parse --show-toplevel)/.llm/todo.md

# Mark as in-progress
todo-complete $(git rev-parse --show-toplevel)/.llm/todo.md --progress

# Explicitly mark as done
todo-complete $(git rev-parse --show-toplevel)/.llm/todo.md --done
```

## Task Format

Each task in `.llm/todo.md` should be independently readable with full context:

```markdown
- [ ] Add user authentication to API routes
  - File: `src/routes/api.ts`
  - Add middleware similar to `src/middleware/auth.ts`
  - Implement JWT validation
  - Return 401 for invalid tokens
  - Depends on: User model in `src/models/user.ts`
  - Expected: All `/api/*` routes require valid JWT
```

Indented lines provide context and are extracted by `todo-get`.

## Workflow Examples

### Basic Single Task

```bash
# Create plan
/plan Add dark mode toggle to settings

# Implement first task
/todo

# Task is now marked [x] and committed
```

### Process All Tasks

```bash
# Create plan
/plan Implement user dashboard with charts

# Implement all tasks automatically
/todo-all
```

### Parallel Development

```bash
# Create plan with multiple independent tasks
/plan Add feature set: auth, dashboard, settings, notifications

# Create 4 parallel worktrees
/worktree 4

# Each worktree has its own Claude Code session
# Tasks are marked [>] in original todo.md
```

## Architecture

```
User Request
    ↓
/plan or /split-tasks
    ↓
Create .llm/todo.md
    ↓
    ├── Single: /todo → todo-get → implement → build → todo-complete
    ├── Multiple: /todo-all → loop(do-todo agent)
    ├── Parallel: /worktree → create worktrees with [>] markers
    └── Harvest: /todo-sweep → append code TODOs
```

## File Locations

- **Todo File**: `<repository-root>/.llm/todo.md`
- **Directory**: `.llm/` (automatically excluded from git via `.git/info/exclude`)
- **Binaries**: `plugins/markdown-tasks/skills/markdown-tasks/bin/todo-get`, `plugins/markdown-tasks/skills/markdown-tasks/bin/todo-complete`
- **Commands**: `plugins/markdown-tasks/commands/*.md`
- **Agent**: `plugins/markdown-tasks/agents/do-todo.md`

## License

MIT
