# Markdown Tasks Plugin

The **markdown-tasks** plugin brings structured task management to Claude Code. Instead of tracking work in your head or losing context between sessions, tasks are stored in a simple markdown file at `.llm/todo.md`.

## Why Use Markdown Tasks?

Claude Code sessions are ephemeral. When you close a session, Claude loses all memory of what was planned, what was completed, and what remains. The markdown-tasks plugin solves this by:

- **Persisting tasks across sessions** - Your task list survives session restarts
- **Providing full context** - Each task contains all information needed to implement it
- **Enabling automation** - Claude can work through tasks autonomously
- **Creating clear history** - Completed tasks are tracked and archived

## Installation

Install from the Claude Code plugin marketplace:

```bash
claude plugins:install motlin-claude-code-plugins
```

## The Task File Format

Tasks are stored in `.llm/todo.md` using standard markdown checkboxes with indented context:

![Task file showing checkbox states](../../assets/markdown-tasks/screenshots/01-todo-file.png)

### Task States

- `[ ]` - Not started, ready to work on
- `[x]` - Completed
- `[!]` - Blocked after a failed attempt

### Task Structure

Each task includes a description line followed by indented context:

```markdown
- [ ] Implement JWT authentication
    - Add token generation and validation
    - Use /path/to/auth.ts as reference
    - Include refresh token support
```

The indented lines provide all the context Claude needs to implement the task independently. This is crucial because tasks are extracted one at a time - Claude cannot see other tasks in the file when working on one.

## Slash Commands

The plugin provides seven slash commands for different workflows:

### /add-one-task

Add a single task to your task list. Provide a description and Claude will expand it with implementation context.

```
/add-one-task Add automated screenshot capture for plugin documentation
```

Claude expands this into a self-contained task with file paths, implementation details, and context:

![Task added confirmation](../../assets/markdown-tasks/screenshots/01-add-one-task.png)

### /do-one-task

Extract and implement the next incomplete task. Claude will:

1. Extract the first `[ ]` task from `.llm/todo.md`
2. Implement it following all the context provided
3. Run precommit checks and fix any issues
4. Commit the changes to git
5. Rebase on the upstream branch
6. Mark the task as complete

### /do-all-tasks

Process all tasks automatically in sequence:

![do-all-tasks autocomplete](../../assets/markdown-tasks/screenshots/02-do-all-tasks-autocomplete.png)

This command loops through all incomplete tasks, implementing each one with its own commit. If a task fails after one attempt, it is marked as blocked `[!]` and Claude moves to the next task.

When all tasks are complete, the task list is archived to `.llm/YYYY-MM-DD-todo.md`.

### /plan-tasks

Transform a planning conversation into actionable tasks. Use this at the end of a discussion where you have explored requirements and approaches but have not started coding.

Claude converts the conversation into self-contained tasks, each with:

- Full absolute paths
- Exact class and function names
- References to similar existing code
- Dependencies and prerequisites
- Expected outcomes

### /sweep-todos

Find all TODO and TASK comments in your codebase and add them to the task list:

```markdown
- [ ] Implement TODO from src/api/client.ts:87: Extract commonality in getRootNodes
- [ ] Implement TODO from test/utils.test.ts:103: Use deep object equality
```

### /unblock-tasks

Recover blocked tasks. `/do-all-tasks` marks a failing task `[!]` and moves on, and archiving carries those tasks into the next task list still blocked. Nothing retries them on its own, so they accumulate quietly across runs:

```
/unblock-tasks
```

Claude surveys every `.llm/*todo*.md` with a dry run first, reports what is blocked and where, and asks before touching anything, because recovery rewrites the archives it reads. Confirmed, each blocked task moves back into `.llm/todo.md` as an open `[ ]` task stamped with the recovery date.

The original `Blocked` line survives alongside it, so the reason the earlier attempt failed travels with the task and the next worker does not repeat that approach.

## Best Practices

### Write Self-Contained Tasks

Each task is extracted and executed in isolation. Include ALL context needed:

```markdown
- [ ] Create SynchronizedBagTest at /path/to/SynchronizedBagTest.java
    - Similar to SynchronizedMutableListTest
    - Extend SynchronizedTestTrait
    - Test addOccurrences(), removeOccurrences(), occurrencesOf()
    - Verify synchronization with assertSynchronized()
```

### Use Absolute Paths

Never use relative paths. Tasks may be executed from different working directories:

```markdown
- [ ] Update configuration in /Users/craig/projects/myapp/src/config.ts
```

### Repeat Shared Context

If multiple tasks share the same background, repeat it in each task. Tasks cannot reference each other:

```markdown
- [ ] Add user registration endpoint
    - Part of auth module refactoring
    - Uses Express.js patterns from /path/to/routes.ts
    - Database models in /path/to/models/

- [ ] Add password reset endpoint
    - Part of auth module refactoring
    - Uses Express.js patterns from /path/to/routes.ts
    - Database models in /path/to/models/
```

## Workflow Integration

The markdown-tasks plugin integrates with other plugins in the collection:

- **git plugin** - Tasks are committed individually with clear messages
- **build plugin** - Precommit checks run after each task
- **orchestration plugin** - Coordinates the full workflow

This enables a hands-off development workflow where Claude works through your task list, committing clean changes along the way.
