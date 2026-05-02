# builtin-tasks Plugin

Task orchestration using Claude Code's built-in task tools. Unlike the [markdown-tasks](../markdown-tasks/README.md) plugin which stores tasks in a file, this plugin uses Claude Code's native `TaskCreate`/`TaskList`/`TaskGet`/`TaskUpdate` API. The main advantage: parallel execution with teams.

## Quick Start

```bash
# Import a Claude Code plan into individual tasks
/import-plan

# Process all tasks sequentially
/do-all-tasks

# Process tasks in parallel with a team of agents
/do-all-with-team
```

## Commands

### `/do-all-with-team` — Parallel Execution

The headline feature. Creates a team of agents that work on tasks concurrently:

- Spawns multiple agents using `TeamCreate`
- Assigns tasks respecting file overlap constraints — if two tasks touch the same files, they run sequentially or one uses a worktree
- Monitors progress and reassigns tasks as agents finish
- Shuts down the team when all tasks are complete

The team-lead skill coordinates which tasks can safely run in parallel. The team-member skill ensures each agent runs the full finish pipeline (build, commit, rebase) before picking up the next task.

### `/do-all-tasks` — Sequential Execution

Works through tasks one at a time, like markdown-tasks. Each task is handled by a `do-task` agent that implements it, runs the finish pipeline, and marks it complete before the next task starts.

Tracks attempt counts to avoid infinite loops — if a task has already been attempted once and failed, it gets skipped.

### `/do-one-task` — Single Task

Finds the first pending, unblocked task and implements it. Useful for manual step-through.

### `/import-plan` — Convert Plans to Tasks

Converts a Claude Code plan file into individual tasks:

- Finds the most recent plan file (or accepts a path)
- Archives the plan to `.llm/plans/` with a dated name
- Creates one task per plan step with standalone context — each task contains all the information an agent needs, since agents only see one task at a time
- Adds three final-pass tasks: full plan verification, `/simplify` review, and `/code-review`

### `/sweep-todos` — Harvest TODO Comments

Finds all `TODO` and `TASK` comments in the codebase and creates a built-in task for each one, including the file path, line number, and surrounding code as context.

## When to Use This vs. markdown-tasks

|                        | builtin-tasks                            | markdown-tasks                                  |
| ---------------------- | ---------------------------------------- | ----------------------------------------------- |
| **Parallel execution** | Yes, with `/do-all-with-team`            | No, sequential only                             |
| **Task persistence**   | Tasks live in Claude Code's session      | Tasks persist in `.llm/todo.md` across sessions |
| **Human editing**      | Tasks managed through commands           | Edit the markdown file directly while it runs   |
| **Add tasks manually** | Through `/sweep-todos` or `/import-plan` | `/add-one-task` or edit the file                |

Use **builtin-tasks** when you want parallel execution within a session. Use **markdown-tasks** when you want tasks that survive across sessions and that you can edit by hand.

## What Gets Installed

- 5 slash commands (`/import-plan`, `/do-one-task`, `/do-all-tasks`, `/do-all-with-team`, `/sweep-todos`)
- 1 agent (`do-task`)
- 2 skills (`team-lead`, `team-member`)

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install builtin-tasks@motlin-claude-code-plugins
```
