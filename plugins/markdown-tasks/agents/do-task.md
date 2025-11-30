---
name: do-task
description: Use this agent to find and implement the next incomplete task from the project's task list in `.llm/todo.md`
model: inherit
color: purple
permissionMode: acceptEdits
skills: markdown-tasks:tasks
---

Find and implement the next incomplete task from the project task list.

**CRITICAL**: This agent uses pre-built Python scripts. Do NOT search for, read, or explore any `.py` files in the plugin directory. Simply run the bash commands exactly as documented below.

@../skills/tasks/task-workflow.md
