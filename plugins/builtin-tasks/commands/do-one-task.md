---
description: Find and implement the next incomplete task using built-in task management
---

Find and implement the next incomplete task using Claude Code's built-in task tools.

## Task Implementation Workflow

### Steps

1. **Find the task** — Call `TaskList` to find pending tasks that are not blocked. Pick the first available task (lowest ID).

2. **Read the task** — Call `TaskGet` with the task ID to read the full description.

3. **Mark as in progress** — Call `TaskUpdate` to set status to `in_progress`.

4. **Implement the task**
   - Think hard about the plan
   - Focus ONLY on implementing this specific task
   - Ignore TODO/TASK comments in source code
   - Work through the implementation methodically
   - Run appropriate tests and validation

5. **Complete the workflow**
   - Verify the build passes using the `build:precommit-runner` agent
   - Commit to git using the `git:commit-handler` agent
   - Rebase on top of the upstream branch with the `git:rebaser` agent

6. **Mark the task complete** — Call `TaskUpdate` to set status to `completed`.
