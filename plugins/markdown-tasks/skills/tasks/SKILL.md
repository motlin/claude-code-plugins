---
name: tasks
description: Work with markdown-based task lists in .llm/todo.md files. Use when managing tasks, working with todo lists, extracting incomplete tasks, marking tasks complete, or implementing tasks from a task list.
---

# Markdown Task Management

The task list lives in `.llm/todo.md`. Never use the `Read` tool on it; change and inspect it only through the scripts below.

`<plugin-root>` is `${CLAUDE_PLUGIN_ROOT}` in Claude Code. In Codex, it is the plugin root that contains this `skills/tasks/SKILL.md` file.

Every script exits 0 on success and 1 on error.

## Scripts

### task_get.py - Extract Next Task

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md
```

Prints the first `[ ]` task with all indented context lines below it. Exits 1 when the file does not exist.

To see more of the queue, select incomplete tasks by 1-based position. Positions count only `[ ]` tasks; `[x]`, `[!]`, and `[>]` tasks are skipped.

```bash
python <plugin-root>/scripts/task_get.py .llm/todo.md --index 3
python <plugin-root>/scripts/task_get.py .llm/todo.md --range 1-10
python <plugin-root>/scripts/task_get.py .llm/todo.md --limit 10
```

Each selected task prints as its checkbox line and context, with a blank line between tasks. `--index` and a `--range` that starts past the last incomplete task exit 1; a `--range` or `--limit` that runs past the end prints the tasks that exist.

### task_add.py - Add New Task

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2"
```

Appends a `[ ]` task, creating `.llm/todo.md` if needed and preserving indentation in multi-line strings.

Add a batch of tasks in one shell command, chaining one call per task with `&&`, so concurrent sessions writing the same file are unlikely to interleave:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "First task
  Context line 1" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Second task"
```

### task_mark.py - Mark Task

```bash
python <plugin-root>/scripts/task_mark.py .llm/todo.md
python <plugin-root>/scripts/task_mark.py .llm/todo.md --marker='!' --reason='precommit failed on the parser rewrite'
```

Changes the first `[ ]` to `[x]`, or to any single non-space character passed as `--marker`. Exits 1 when no incomplete task remains.

`--reason` appends an indented line to the end of the task body:

```markdown
- [!] Require authentication on API routes.
  Reuse `validateJwt` from `/workspace/project/src/auth/tokens.ts`.
  Blocked 2026-08-19 session 94aec27b: validateJwt does not exist; the repo uses `verifyToken`
```

The reason travels with the task through archive and recovery, and `task_get.py` hands it to the next attempt. Quote the concrete failure (the failing command, the assertion, the missing symbol) rather than restating the task.

`--reason` is required with `--marker='!'`; without it the script exits 1 and leaves the file untouched.

To mark a task other than the first, name it:

```bash
python <plugin-root>/scripts/task_mark.py .llm/todo.md --index 3 --marker='>'
python <plugin-root>/scripts/task_mark.py .llm/todo.md --title 'Require authentication on API routes.'
```

`--index` counts `[ ]` tasks the same way `task_get.py` does. `--title` matches the first `[ ]` or `[>]` task whose text after the checkbox equals the title exactly, so it can complete or block a task that was claimed with `[>]`. Positions shift once a task is marked, so prefer `--title` when marking several tasks in turn. A missing title or out-of-range index exits 1 and leaves the file untouched.

### task_archive.py - Archive Task List

```bash
python <plugin-root>/scripts/task_archive.py .llm/todo.md
```

Moves the file to `.llm/YYYY-MM-DD-todo.md`. Blocked `[!]` tasks are carried forward into a fresh `.llm/todo.md`, still marked `[!]`. Prints the archive path and the carried-forward count.

### task_unblock.py - Recover Blocked Tasks

```bash
python <plugin-root>/scripts/task_unblock.py .llm --dry-run
python <plugin-root>/scripts/task_unblock.py .llm
```

Scans every `.llm/*todo*.md`, including the live `.llm/todo.md`, and moves each `[!]` task into `.llm/todo.md` as an open `[ ]` task stamped with an indented `Recovered <yyyy-mm-dd> session <session-id>` line. Existing `Blocked` lines are kept. Recovery is a move, so re-running cannot duplicate a task; emptied archive files stay on disk. Exits 0 when nothing is blocked.

Recovery rewrites historical archives. Always run `--dry-run` first and confirm the report with the user.

## Task Format

A task starts with one of these markers:

- `[ ]` - Ready
- `[x]` - Completed
- `[!]` - Blocked after a failed attempt

Each task is extracted and executed in isolation, so it must carry all the context needed to implement it in indented lines:

- Absolute file paths
- Exact function/class names
- Existing patterns to follow
- Dependencies and prerequisites
- Expected outcome

Repeat shared context in every related task. Never reference other tasks.

## Plan Files

Before adding tasks from a plan, store the plan at `.llm/plans/<yyyy-mm-dd>-<descriptive-name>.md` (for example, `2025-12-04-thread-safety-tests.md`), creating the directory if needed. A Claude Code plan-mode file under `~/.claude/plans/` is moved there, not copied. Include the archived plan's absolute path in every task.
