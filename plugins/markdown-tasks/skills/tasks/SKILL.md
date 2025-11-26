---
name: markdown-tasks
description: Work with markdown-based task lists in .llm/todo.md files. Use when managing tasks, working with todo lists, extracting incomplete tasks, marking tasks complete, or implementing tasks from a task list.
---

# Markdown Task Management

This skill enables working with markdown task lists stored in `.llm/todo.md` at the repository root.

See [shared/task-format.md](../../shared/task-format.md) for task format and location.

## Scripts

| Script             | Purpose                  | Documentation                                             |
| ------------------ | ------------------------ | --------------------------------------------------------- |
| `task_get.py`      | Extract first incomplete | [task-get.md](../../shared/scripts/task-get.md)           |
| `task_add.py`      | Add new task             | [task-add.md](../../shared/scripts/task-add.md)           |
| `task_complete.py` | Mark task done           | [task-complete.md](../../shared/scripts/task-complete.md) |
| `task_archive.py`  | Archive completed list   | [task-archive.md](../../shared/scripts/task-archive.md)   |

## Dependencies

These scripts require Python 3 with standard library only (no external packages needed).
