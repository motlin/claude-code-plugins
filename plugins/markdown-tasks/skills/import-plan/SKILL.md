---
name: import-plan
description: Import a plan markdown file into .llm/todo.md as self-contained tasks, one per plan step plus verification and archive tasks. Use after plan mode or when the user names a plan file.
---

# Import Plan

Turn a plan file into tasks in `.llm/todo.md`, each pointing at one step of the archived plan.

Use the `markdown-tasks:tasks` skill for task format and script path rules. `<plugin-root>` is `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, it is the plugin root that contains this `skills/import-plan/SKILL.md` file.

## Locate the Plan File

- Use the path the user gave after the skill name.
- Otherwise, use the plan file you wrote or edited earlier in this conversation.
- Otherwise, in Claude Code, pick the most recently modified `.md` file in `~/.claude/plans/` and confirm it with the user via `AskUserQuestion`, since concurrent sessions write plans to the same directory. If there are none, tell the user and stop.
- In Codex, ask for the path.

Read the plan to understand its steps.

## Archive the Plan Locally

Move (do not copy) the plan to `.llm/plans/<yyyy-mm-dd>-<descriptive-name>.md`, creating the directory if needed. Pick a concise name from the plan content, such as `add-import-plan-command`. Use the archived file's **absolute path** in every task.

## Create Tasks

Compose every task first, then add them all in one shell command that chains one `task_add.py` call per task with `&&`. Separate commands widen the window in which concurrent imports can interleave.

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

Each plan-step task includes what the step accomplishes, the line `Read and follow step N from the plan at <absolute-path-to-archived-plan>`, and the key file paths and identifiers from that step.

The chain always ends with the same two tasks:

- The verification task compares the whole plan against the implemented code and flags any requirement, edge case, or detail that was missed.
- The archive task creates `.llm/plans/done/` if needed and moves the plan there, so future sessions do not mistake it for pending work. It runs only after verification finds no gaps; otherwise the plan stays in `.llm/plans/` with a note about what is missing.

## Confirm

Report how many tasks were created (for example, "Created 7 tasks (5 plan steps + 1 verification + 1 archive)") and where the plan was archived.
