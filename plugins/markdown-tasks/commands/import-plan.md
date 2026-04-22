---
argument-hint: plan file path
description: Import a Claude plan file into the task list as individual tasks
---

# Import Plan

Convert a structured plan file from Claude Code's plan mode into individual tasks in `.llm/todo.md`, where each task references a specific step in the archived plan.

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

For each step in the plan, add a task using:

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2"
```

Creates the `.llm/` directory and `todo.md` file if they do not exist, and appends the new task with a `[ ]` checkbox. The script preserves all indentation in multi-line strings.

**Exit codes**: 0 (success), 1 (error)

Each task must include:

1. A brief description of what the step accomplishes
2. An instruction line: `Read and follow step N from the plan at \`<absolute-path-to-archived-plan>\``
3. Key file paths and identifiers mentioned in that step (for standalone context)

## Task Format

The task list is in `.llm/todo.md`.

NEVER use the `Read` tool on `.llm/todo.md`. Always interact with the task list exclusively through the Python scripts.

### Task States

- `[ ]` - Not started (ready to work on)
- `[x]` - Completed
- `[!]` - Blocked after failed attempt

### Standalone Context

Each task is extracted and executed in isolation. The `task_get.py` script extracts only one task at a time - it cannot see other tasks in the file. Therefore:

1. Every task must contain ALL context needed to implement it
2. Repeat shared context in every related task - if 5 tasks share the same background, repeat it 5 times
3. Never reference other tasks - phrases like "similar to task above" are useless
4. Include the full picture - source of inspiration, files involved, patterns to follow
5. Use full absolute paths, exact class/function names, and specific implementation details

## Create Final-Pass Tasks

After all plan-step tasks are created, add three additional tasks using the same `task_add.py` script. Each task follows the same standalone context rules as plan-step tasks (plan path, self-contained description).

**Task 1: Verify full plan implementation**

Read the entire archived plan file and compare against the implemented code. Check that every requirement, edge case, and detail from the plan has been addressed. Flag anything missed.

Include the archived plan path so the implementing agent can read and verify against it.

**Task 2: Run /simplify on recent commits**

Run `/simplify` to review the code changes from this work stream for reuse opportunities, quality, and efficiency. Scope: all commits on the current branch since it diverged from upstream.

**Task 3: Run /code-review on recent commits**

Run `/code-review` to review the code changes from this work stream. Fix any important findings. Scope: all commits on the current branch since it diverged from upstream.

## Confirm

Tell the user:

- How many tasks were created, broken down by type (e.g., "Created 8 tasks (5 plan steps + 3 final-pass tasks)")
- Where the plan was archived
