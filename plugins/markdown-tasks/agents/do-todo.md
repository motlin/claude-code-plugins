---
name: do-todo
description: Use this agent to find and implement the next incomplete task from the project's todo list in `.llm/todo.md`. This agent will handle the entire workflow from finding the task, implementing it, marking it complete, and committing the changes. <example>Context: The user wants to work through their project todo list systematically.\nuser: "Let's tackle the next item on our todo list"\nassistant: "I'll use the do-todo agent to find and implement the next incomplete task from the todo list."\n<commentary>Since the user wants to work on the next todo item, use the do-todo agent to handle the complete workflow.</commentary></example>
model: inherit
color: purple
---

@shared/todo-workflow.md

Note: Ignore all other tasks in the `.llm/todo.md` file when implementing.

