---
name: import-plan
description: Import a plan markdown file into .llm/todo.md as self-contained tasks, one per plan step plus verification and archive tasks. Use after plan mode or when the user names a plan file.
---

# Import Plan

Convert a structured plan file from Claude Code's plan mode into individual tasks in `.llm/todo.md`, where each task references a specific step in the archived plan.

Use the `markdown-tasks:tasks` skill for task format and script path rules.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/import-plan/SKILL.md` file.

## Locate the Plan File

- If the user provided a plan file path after the skill name, use it.
- Otherwise, use the plan file you remember writing or editing earlier in this conversation.
- If no plan was written in this conversation, pick the most recently modified `.md` file in `~/.claude/plans/`, then confirm with the user via `AskUserQuestion` that it's the right plan — concurrent Claude sessions may be writing other plans into the same directory.
- If `~/.claude/plans/` has no `.md` files, tell the user and stop.
- In Codex, ask for the path when the conversation does not identify a stored plan.

Read the plan file first to understand its structure and steps.

## Archive the Plan Locally

- Create the `.llm/plans/` directory if it does not exist.
- Choose a concise, descriptive name based on the plan content (e.g., `add-import-plan-command`).
- Move the file (do not copy it): `~/.claude/plans/<original-name>.md` → `.llm/plans/<yyyy-mm-dd>-<descriptive-name>.md`.
- Record the **absolute path** to the archived file for use in tasks.

## Create Tasks

Compose every task first — all plan-step tasks plus the verification and archive tasks below — then add them all in one shell command that chains one `task_add.py` call per task with `&&`:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "First task description
  Read and follow step 1 from the plan at <absolute-path-to-archived-plan>
  Context line 1
  Context line 2" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Second task description
  Read and follow step 2 from the plan at <absolute-path-to-archived-plan>
  Context line 1" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Verify the full plan implementation
  Read the entire plan at <absolute-path-to-archived-plan>" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Archive the completed plan
  Move <absolute-path-to-archived-plan> into .llm/plans/done/ only after verification succeeds"
```

Running the whole batch as one command keeps the window in which `.llm/todo.md` is being written extremely short, so when two sessions import plans at the same time their tasks are far less likely to interleave. Never add tasks across separate commands — collect them and run a single chained command.

Each plan-step task must include:

- A brief description of what the step accomplishes.
- An instruction line: `Read and follow step N from the plan at \`<absolute-path-to-archived-plan>\``.
- Key file paths and identifiers mentioned in that step, for standalone context.

## Verification and Archive Tasks

The last two calls in the chain are always the same pair, and both carry the archived plan's absolute path like every other task.

The verification task reads the entire archived plan and compares it against the implemented code, checking that every requirement, edge case, and detail from the plan was addressed and flagging anything missed.

The archive task moves the plan out of open work so future sessions don't mistake it for pending: create `.llm/plans/done/` if it does not exist, then `mv <absolute-path-to-archived-plan> .llm/plans/done/`. It runs only after verification confirmed the plan is fully implemented — if verification flagged gaps, the plan stays in `.llm/plans/` with a note about what's missing.

## Confirm

Tell the user:

- How many tasks were created (e.g., "Created 7 tasks (5 plan steps + 1 verification + 1 archive)")
- Where the plan was archived
