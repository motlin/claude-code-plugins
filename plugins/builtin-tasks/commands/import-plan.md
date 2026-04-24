---
argument-hint: plan file path
description: Import a Claude plan file into the built-in task list
---

# Import Plan

Convert a structured plan file from Claude Code's plan mode into individual tasks using `TaskCreate`, where each task references a specific step in the archived plan.

## Locate the Plan File

- If `$ARGUMENTS` is provided and non-empty, use it as the plan file path
- Otherwise, list `~/.claude/plans/` sorted by modification time (newest first) and use the most recent `.md` file
- If no plan file is found, tell the user and stop

Read the plan file to understand its structure and steps.

## Archive the Plan Locally

1. Create the `.llm/plans/` directory if it does not exist
2. Choose a concise, descriptive name based on the plan content (e.g., `add-import-plan-command`)
3. Move the file: `~/.claude/plans/<original-name>.md` → `.llm/plans/<yyyy-mm-dd>-<descriptive-name>.md`
4. Record the **absolute path** to the archived file for use in tasks

## Create Tasks

For each step in the plan, create a task using `TaskCreate` with:

- **`subject`**: A brief imperative description of the step (e.g., "Add validation to user input handler")
- **`activeForm`**: Present continuous form for spinner text (e.g., "Adding validation to user input handler")
- **`description`**: Full standalone context including all fields below

Each task's `description` must include:

1. A brief description of what the step accomplishes
2. An instruction line: `Read and follow step N from the plan at \`<absolute-path-to-archived-plan>\``
3. Key file paths and identifiers mentioned in that step (for standalone context)

### Standalone Context

Each task is executed in isolation by an agent that can only see one task at a time via `TaskGet`. Therefore:

1. Every task must contain ALL context needed to implement it
2. Repeat shared context in every related task — if 5 tasks share the same background, repeat it 5 times
3. Never reference other tasks — phrases like "similar to task above" are useless
4. Include the full picture — source of inspiration, files involved, patterns to follow
5. Use full absolute paths, exact class/function names, and specific implementation details

## Create Verification Task

After all plan-step tasks are created, add one additional task using `TaskCreate`. It follows the same standalone context rules as plan-step tasks (plan path, self-contained description).

**Verify full plan implementation**

Read the entire archived plan file and compare against the implemented code. Check that every requirement, edge case, and detail from the plan has been addressed. Flag anything missed.

Include the archived plan path so the implementing agent can read and verify against it.

## Confirm

Tell the user:

- How many tasks were created (e.g., "Created 6 tasks (5 plan steps + 1 verification)")
- Where the plan was archived
