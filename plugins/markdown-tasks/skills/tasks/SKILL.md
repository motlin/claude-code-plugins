---
name: markdown-tasks
description: Work with markdown-based task lists in .llm/todo.md files. Use when managing tasks, working with todo lists, extracting incomplete tasks, marking tasks complete, or implementing tasks from a task list.
---

# Markdown Task Management

This skill enables working with the markdown task list stored in `.llm/todo.md`.

## Important: Do Not Explore Plugin Directory

The scripts referenced below are part of this plugin and are pre-verified to work correctly. Do NOT:

- Search for or read the `.py` script files
- Explore the `${CLAUDE_PLUGIN_ROOT}` directory
- Try to understand the script implementation

Simply **run the bash commands exactly as shown**. The scripts handle all the complexity internally.

## Scripts

These scripts require Python 3 with standard library only (no external packages needed).

@task-get.md

@task-add.md

@task-complete.md

@task-archive.md
