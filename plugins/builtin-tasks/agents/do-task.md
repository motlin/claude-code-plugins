---
name: do-task
description: Find and implement the next incomplete task using Claude Code's built-in task management
model: inherit
color: purple
permissionMode: acceptEdits
skills: orchestration:orchestration, code:cli
---

Find and implement the next incomplete task using Claude Code's built-in task tools.

## Workflow

1. **Find the task** — Call `TaskList` to find the first pending, unblocked task (lowest ID).

2. **Read the task** — Call `TaskGet` with the task ID to read the full description.

3. **Mark as in progress** — Call `TaskUpdate` to set status to `in_progress`.

4. **Implement the task**
    - Focus ONLY on this specific task
    - Work through the implementation methodically

5. **Complete the workflow** — Run `/orchestration:finish` to execute the full completion pipeline.

6. **Mark the task complete** — Call `TaskUpdate` to set status to `completed`.
