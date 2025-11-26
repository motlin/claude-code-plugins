---
argument-hint: task description
description: Add a task to the project task list
---

Add a task to the project task list.

If the user provided a description, it will appear here:

<description>
$ARGUMENTS
</description>

## Steps

1. Extract the description from the user's input
2. If no description was provided, ask the user for one
3. Add the task:

@../shared/scripts/task-add.md

4. Confirm to the user that the task was added

## Notes

- The description should be clear and actionable
- Do not include the checkbox syntax in the description (the script adds it)
