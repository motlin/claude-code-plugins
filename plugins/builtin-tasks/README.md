# builtin-tasks Plugin

`builtin-tasks` turns Claude Code's built-in task list into an implementation queue. It can fill the
queue from a plan or source comments, execute tasks one at a time, or distribute independent work
across a Claude Code team.

This plugin is available only in the Claude Code marketplace. Its commands and agent rely on
`TaskList`, `TaskGet`, `TaskUpdate`, `TaskCreate`, and the optional team tools. Use
[markdown-tasks](../markdown-tasks/README.md) for Codex or for a queue stored in
`.llm/todo.md`.

## Install

Register the marketplace and install the plugin:

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install builtin-tasks@motlin-claude-code-plugins
```

Task execution calls the repository's finish pipeline. Install the workflow plugins it delegates
to:

```bash
claude plugin install orchestration@motlin-claude-code-plugins
claude plugin install build@motlin-claude-code-plugins
claude plugin install git@motlin-claude-code-plugins
claude plugin install code@motlin-claude-code-plugins
```

Run implementation commands in a Git repository where `git-test` is installed and configured.
Each task is committed before the pipeline validates it with
`git test run HEAD --retest --verbose --verbose`.

## Commands

| Command                             | Result                                                |
| ----------------------------------- | ----------------------------------------------------- |
| `/builtin-tasks:import-plan <path>` | Archives a plan and creates built-in tasks            |
| `/builtin-tasks:sweep-todos`        | Creates tasks from `TODO` and `TASK` source comments  |
| `/builtin-tasks:do-one-task`        | Implements the lowest-ID available task               |
| `/builtin-tasks:do-all-tasks`       | Processes available tasks sequentially                |
| `/builtin-tasks:do-all-with-team`   | Assigns independent tasks to a coordinated agent team |

The plugin has no add-one command. Create an individual item with Claude Code's task tools, or use
one of the two queue-population commands.

## Build a Queue

### Import a Plan

Supply a Claude Code plan file:

```text
/builtin-tasks:import-plan ~/.claude/plans/parser-cleanup.md
```

The command moves the plan into `.llm/plans/` with a dated descriptive name. It creates one
self-contained built-in task per plan step and includes the archived plan's absolute path in every
task. It then adds a whole-plan verification task and a final archive task. The archive task moves
the plan into `.llm/plans/done/` only after verification succeeds.

If the command receives no path, it uses a plan remembered in the conversation. When there is no
remembered plan, it proposes the most recently modified Markdown file under `~/.claude/plans/` and
asks before moving it.

### Sweep Source Comments

Run:

```text
/builtin-tasks:sweep-todos
```

For every `TODO` or `TASK` match, the command records the source path, line number, original text,
and nearby code in a new built-in task. It does not remove the source comment or deduplicate
matches, so review results when generated or vendored files are present.

## Execute the Queue

### Implement One Task

```text
/builtin-tasks:do-one-task
```

The command selects the pending, unblocked task with the lowest ID, reads its complete description,
and marks it in progress. After implementation and task-specific checks, the finish pipeline
commits, validates, rebases, and reviews the change. Only a successful finish allows the command to
mark the built-in task completed.

### Run Sequentially

```text
/builtin-tasks:do-all-tasks
```

The batch command starts a fresh `builtin-tasks:do-task` agent for each available task and waits for
that task's commit before selecting another. It checks the committed `HEAD` between tasks and stops
if the cached `git-test` result is bad or unknown. A task is attempted once per run, preventing a
failed item from creating an endless loop.

Optional trailing instructions can narrow the run:

```text
/builtin-tasks:do-all-tasks Process only parser tasks
```

### Run with a Team

```text
/builtin-tasks:do-all-with-team
```

This command reads task dependencies, creates a Claude Code team, assigns work, monitors members,
and removes the team when the run ends. Every assignment still produces one task commit. Tasks that
touch the same files must be serialized or isolated in worktrees.

Use this mode only when Claude Code exposes `TeamCreate`, `Task`, and `TeamDelete` and the queue has
work that can proceed independently. For ordered or overlapping tasks, the sequential command has
the appropriate execution model.

## Boundaries

- Queue state lives in Claude Code, not in `.llm/todo.md`.
- Blocked tasks are skipped until their dependencies or status change.
- Import and sweep commands create tasks; they do not implement work.
- Every implementation command expects the companion finish workflow and a usable Git repository.
- Team coordination prevents simultaneous file overlap only when the task descriptions identify
  those files accurately.
