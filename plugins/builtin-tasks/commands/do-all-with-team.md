---
argument-hint: optional instructions
description: Process all tasks in parallel using a team of agents
---

Process all tasks in parallel using a team of agents and Claude Code's built-in task tools.

If the user provided additional instructions, they will appear here:

<instructions>
$ARGUMENTS
</instructions>

If the user did not provide instructions, work through ALL incomplete tasks until NONE remain.

## Steps

1. Read the `builtin-tasks:team-lead` skill for coordination guidelines
2. Call `TaskList` to review all pending tasks and their dependencies
3. Create a team with `TeamCreate`
4. Create tasks in the team's task list based on the pending built-in tasks
5. Spawn team members using the `Task` tool, telling each to read the `builtin-tasks:team-member` skill
6. Assign tasks to team members, respecting file overlap constraints from the team-lead skill
7. Monitor progress, reassign tasks as members complete their work, and handle failures
8. When all tasks are complete, shut down team members and clean up with `TeamDelete`
