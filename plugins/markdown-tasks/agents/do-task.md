---
name: do-task
description: Use this agent to find and implement the next incomplete task from the project's task list in `.llm/todo.md`. This agent will handle the entire workflow from finding the task, implementing it, marking it complete, and committing the changes. <example>Context: The user wants to work through their project task list systematically.\nuser: "Let's tackle the next item on our task list"\nassistant: "I'll use the do-task agent to find and implement the next incomplete task from the task list."\n<commentary>Since the user wants to work on the next task item, use the do-task agent to handle the complete workflow.</commentary></example>
model: inherit
color: purple
permissionMode: acceptEdits
skills: markdown-tasks:tasks
---

@markdown-tasks:shared/task-workflow.md
