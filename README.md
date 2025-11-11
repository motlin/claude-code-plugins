# Markdown Tasks Plugin for Claude Code

Keep your tasks in a simple markdown file (`todo.md`) and let Claude Code implement them automatically.

## Naming

This plugin uses "task" terminology (e.g., `/do-one-task`, `/add-one-task`) instead of "todo" to avoid conflicts with Claude Code's built-in `/todos` command.

## Quick Start

Most common workflows:

```bash
/add-one-task <description>  # Add a single task to the list
/do-all-tasks                # Implement all tasks in .llm/todo.md
/sweep-todos                 # Find TODO comments and add them to the list
```

You can also manually edit `.llm/todo.md` directly or ask Claude to flesh out the task list.

## Installation

```bash
# Add the marketplace
/plugin marketplace add motlin/claude-code-plugins

# Install the markdown-tasks plugin
/plugin install markdown-tasks
```

If you are behind a proxy, you can install the marketplace from a directory.

```bash
git clone https://github.com/motlin/claude-code-plugins.git/ ~/.claude/plugins/marketplaces/motlin-claude-code-plugins
claude
/plugin marketplace add ~/.claude/plugins/marketplaces/motlin-claude-code-plugins
/plugin install markdown-tasks
```

This installs:
- 5 slash commands (`/plan-tasks`, `/do-one-task`, `/add-one-task`, `/do-all-tasks`, `/sweep-todos`)
- 1 agent (`do-task`)
- 1 skill (`markdown-tasks`) with bundled Python scripts

No additional setup required - the skill's scripts are automatically available when the plugin is installed.

## Permissions Configuration

To enable Claude Code to run uninterrupted for as long as possible, configure it to skip permission prompts. Proceed with caution.

### Option 1: Permissive Settings (Recommended)

Configure permissive permissions in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash",
      "Edit",
      "MultiEdit",
      "Read",
      "WebSearch",
      "Write",
      "Skill(markdown-tasks:markdown-tasks)",
      "WebFetch(domain:github.com)"
    ],
    "deny": [
      "Bash(git add --all:*)",
      "Bash(git add --force:*)",
      "Bash(git add -A:*)",
      "Bash(git add -f:*)",
      "Bash(git commit -a:*)",
      "Bash(git push:*)",
      "Bash(git reset --hard:*)",
      "Bash(git worktree remove --force:*)",
      "Bash(rm -rf:*)",
      "Edit(~/.claude/settings.json)",
      "MultiEdit(~/.claude/settings.json)"
    ],
    "ask": []
  }
}
```

### Option 2: CLI Flag

For per-session control:

```bash
claude --dangerously-skip-permissions /todo
```

## Commands

### `/add-one-task` - Add Single Task

Adds a single task to `.llm/todo.md`.

```bash
/add-one-task Implement user authentication with OAuth
```

### `/do-all-tasks` - Process All Tasks

Works through all incomplete tasks sequentially using the `do-task` agent.

```bash
/do-all-tasks
```

Each task is implemented in complete isolation:
- The `do-task` agent reads only the single task description and its context
- No information about other tasks pollutes the agent's context
- Prevents confusion between similar tasks or accidentally implementing the wrong feature
- Each task gets its own commit

When a task fails, it's marked as blocked (`[!]`) and `/do-all-tasks` skips it and continues with the next task. You can manually change `[!]` back to `[ ]` in `.llm/todo.md` to retry the task later.

### `/sweep-todos` - Harvest Code TODOs

Finds all TODO comments in codebase and adds them to `.llm/todo.md`.

```bash
/sweep-todos
```

Example output showing discovered TODOs:

```markdown
### TODOs from Codebase (found by /sweep-todos)

- [ ] Implement TODO from src/utils/validators.js:42: Add email format validation
- [ ] Implement TODO from src/components/UserForm.tsx:78: Add phone number field with country code selector
- [ ] Implement TODO from src/api/auth.ts:156: Implement rate limiting for login attempts
- [ ] Implement TODO from tests/integration/payment.test.ts:23: Add test coverage for refund scenarios
- [ ] Implement TODO from src/services/cache.ts:91: Add explicit generics support for type safety
```

### `/do-one-task` - Work on Next Task

Finds and implements exactly one incomplete task.

```bash
/do-one-task
```

Workflow:
1. Extracts first `[ ]` task
2. Implements the task
3. Runs build pipeline (comment-cleaner, precommit-runner, git-commit-handler, git-rebaser)
4. Marks task as `[x]`

Uses the `do-task` agent internally.

#### `do-task` Agent

Implements a single task with full build pipeline and marks it complete.

Used internally by `/do-one-task` and `/do-all-tasks` commands.

## Other Commands

### `/plan-tasks` - Capture Conversation Planning

Captures conversation planning and requirements into actionable tasks. Use at the **end of a planning discussion** before starting implementation.

```bash
/plan-tasks
```

Transforms discussion context into granular, self-contained tasks in `.llm/todo.md`.

## Task States

Tasks use markdown checkboxes with different states:

- `[ ]` - Ready to work on
- `[x]` - Completed and committed
- `[!]` - Blocked after failed attempt

## Scripts

The plugin includes Python scripts in `plugins/markdown-tasks/skills/markdown-tasks/scripts/`:

- `task_get.py` and `task_complete.py` - Extract and mark individual tasks
- `task_add.py` - Add new tasks to the list
- `task_archive.py` - Archive completed task lists

These tools prevent context pollution by ensuring agents only see the specific task they're working on, not the entire task list.

### Benefits

When implementing tasks, agents receive only:
- The single task description
- Its context lines
- Nothing about other unrelated tasks

This focused context prevents context rot:
- Confusion between similar tasks
- Accidentally implementing the wrong feature
- LLM attention being split across multiple objectives

### `task_get.py`

Extracts exactly one task with its context.

```bash
python3 plugins/markdown-tasks/skills/markdown-tasks/scripts/task_get.py $(git rev-parse --show-toplevel)/.llm/todo.md
```

### `task_complete.py`

Marks the first incomplete task as done.

```bash
python3 plugins/markdown-tasks/skills/markdown-tasks/scripts/task_complete.py $(git rev-parse --show-toplevel)/.llm/todo.md
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

Indented lines provide context and are extracted by `task-get`.

## Workflow Examples

### Basic Single Task

```bash
# Add a task
/add-one-task Add dark mode toggle to settings

# Implement it
/do-one-task

# Task is now marked [x] and committed
```

### Process All Tasks

```bash
# Add multiple tasks
/add-one-task Implement user dashboard with charts
/add-one-task Add authentication
/add-one-task Create settings page

# Implement all tasks
/do-all-tasks
```

### Code Review with TODOs

```bash
# During code review, leave TODO comments in the code
#   // TODO: Add rate limiting to login endpoint
#   // TODO: Implement password reset functionality
#   // TODO: Add session timeout handling

# Sweep all TODOs into .llm/todo.md
/sweep-todos

# Review the collected tasks in .llm/todo.md and add context if needed

# Implement all tasks
/do-all-tasks
```

