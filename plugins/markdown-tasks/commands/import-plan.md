---
argument-hint: plan file path
description: Import a Claude plan file into the task list as individual tasks
---

# Import Plan

Convert a structured plan file from Claude Code's plan mode into individual tasks in `.llm/todo.md`, where each task references a specific step in the archived plan.

## Locate the Plan File

- If `$ARGUMENTS` is provided, use it as the plan file path.
- Otherwise, use the plan file you remember writing or editing earlier in this conversation.
- If no plan was written in this conversation, pick the most recently modified `.md` file in `~/.claude/plans/`, then confirm with the user via `AskUserQuestion` that it's the right plan — concurrent Claude sessions may be writing other plans into the same directory.
- If `~/.claude/plans/` has no `.md` files, tell the user and stop.

Read the plan file to understand its structure and steps.

## Archive the Plan Locally

1. Create the `.llm/plans/` directory if it does not exist
2. Choose a concise, descriptive name based on the plan content (e.g., `add-import-plan-command`)
3. Move the file: `~/.claude/plans/<original-name>.md` → `.llm/plans/<yyyy-mm-dd>-<descriptive-name>.md`
4. Record the **absolute path** to the archived file for use in tasks

## Create Tasks

Compose every task first — all plan-step tasks plus the verification and archive tasks below — then add them all in a **single** bash command that chains one `task_add.py` call per task with `&&`:

```bash
python ${CLAUDE_PLUGIN_ROOT}/scripts/task_add.py .llm/todo.md "First task description
  Context line 1
  Context line 2" && \
python ${CLAUDE_PLUGIN_ROOT}/scripts/task_add.py .llm/todo.md "Second task description
  Context line 1" && \
python ${CLAUDE_PLUGIN_ROOT}/scripts/task_add.py .llm/todo.md "Third task description"
```

Running the whole batch as one command keeps the window in which `.llm/todo.md` is being written extremely short, so when two sessions import plans at the same time their tasks are far less likely to interleave. Never add tasks across separate commands — collect them and run a single chained command.

Each `task_add.py` call creates the `.llm/` directory and `todo.md` file if they do not exist, and appends the task with a `[ ]` checkbox. The script preserves all indentation in multi-line strings.

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

## Create Verification Task

Include one additional `task_add.py` call in the same chained command, after all plan-step tasks. It follows the same standalone context rules as plan-step tasks (plan path, self-contained description).

**Verify full plan implementation**

Read the entire archived plan file and compare against the implemented code. Check that every requirement, edge case, and detail from the plan has been addressed. Flag anything missed.

Include the archived plan path so the implementing agent can read and verify against it.

## Create Archive Task

Include one final `task_add.py` call in the same chained command, after the verification task. It follows the same standalone context rules (plan path, self-contained description).

**Archive the completed plan**

Move the plan file into the done directory so future sessions don't mistake it for open work: create `.llm/plans/done/` if it does not exist, then `mv <absolute-path-to-archived-plan> .llm/plans/done/`. Only move it if the verification task confirmed the plan is fully implemented — if verification flagged gaps, leave the plan in `.llm/plans/` and note what's missing.

Include the absolute path of the archived plan in the task description.

## Confirm

Tell the user:

- How many tasks were created (e.g., "Created 7 tasks (5 plan steps + 1 verification + 1 archive)")
- Where the plan was archived
