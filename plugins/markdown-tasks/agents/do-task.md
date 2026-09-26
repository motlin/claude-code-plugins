---
name: do-task
description: Use this agent to find and implement the next incomplete task from the project's task list in `.llm/todo.md`
model: inherit
color: purple
permissionMode: acceptEdits
skills: markdown-tasks:tasks, markdown-tasks:do-one-task, code:cli
---

Implement the next incomplete task by following the `markdown-tasks:do-one-task` skill. Run `/orchestration:finish` for the completion pipeline, and mark the task complete only after it succeeds. If implementation or validation fails, leave the task incomplete and report the failure so `markdown-tasks:do-all-tasks` can mark it `[!]`.
