# builtin-tasks Plugin

Run repository work from Claude Code's built-in task list. The plugin can turn a plan or source-code
comments into tasks, implement one task, process a queue sequentially, or coordinate independent
tasks across a team.

This is a Claude Code plugin. It depends on Claude-specific task, agent, and team tools and is not
available through this repository's Codex marketplace. For a task list stored in the repository,
or for Codex support, use [markdown-tasks](../markdown-tasks/README.md).

## Choose a Workflow

| Goal                                     | Command                           | Execution model                       |
| ---------------------------------------- | --------------------------------- | ------------------------------------- |
| Implement the next available task        | `/builtin-tasks:do-one-task`      | One agent and one commit              |
| Work through the available queue         | `/builtin-tasks:do-all-tasks`     | Agents run one at a time              |
| Turn a plan into built-in tasks          | `/builtin-tasks:import-plan`      | Task creation only                    |
| Collect `TODO` and `TASK` comments       | `/builtin-tasks:sweep-todos`      | Task creation only                    |
| Implement independent tasks concurrently | `/builtin-tasks:do-all-with-team` | Coordinated team with multiple agents |

Use the single-task or sequential batch commands when tasks touch the same files, must land in
order, or do not justify team setup. Use the team command only when several tasks can proceed
independently. The team lead must account for task dependencies and file overlap before assigning
work concurrently.

## Installation

Add this repository's Claude Code marketplace, then install the plugin:

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install builtin-tasks@motlin-claude-code-plugins
```

The task executors call the repository's finish workflow to commit, test, rebase, and review each
change. Install its companion plugins as well:

```bash
claude plugin install orchestration@motlin-claude-code-plugins
claude plugin install build@motlin-claude-code-plugins
claude plugin install git@motlin-claude-code-plugins
claude plugin install code@motlin-claude-code-plugins
```

Run implementation commands inside a Git repository prepared for that finish workflow. In
particular, `git-test` must be installed and configured for the repository because task execution
validates committed `HEAD` with `git test run HEAD --retest --verbose --verbose`.

The team workflow has one additional requirement: Claude Code must expose its team tools, including
`TeamCreate`, `Task`, and `TeamDelete`. If those tools are unavailable, use the sequential batch
workflow.

## Populate the Task List

The plugin operates on Claude Code's built-in task list. It does not create or consume
`.llm/todo.md`, and it does not provide an `add-one-task` command. Start with tasks already created
through Claude Code's task tools, import a plan, or sweep the repository for comments.

Task descriptions should be self-contained. A task executor retrieves one task, focuses on that
task alone, and does not use neighboring tasks as implementation context.

### Import a Plan

Pass a Claude Code plan file to `/builtin-tasks:import-plan`:

```text
/builtin-tasks:import-plan ~/.claude/plans/parser-cleanup.md
```

The command reads the plan, moves it into `.llm/plans/` under a dated descriptive filename, and
creates one built-in task for each plan step. Every created task includes the archived plan's
absolute path, its step number, and enough file and identifier context to stand on its own.

The import also appends two tasks:

1. A verification task that compares the finished implementation with the entire plan.
2. An archive task that moves the plan into `.llm/plans/done/` only after verification confirms the
   plan is complete.

When no path is supplied, the command uses a plan remembered from the current conversation. If
there is no remembered plan, it proposes the most recently modified Markdown file under
`~/.claude/plans/` and asks for confirmation. Importing moves the source plan rather than copying
it.

### Sweep Source Comments

Run:

```text
/builtin-tasks:sweep-todos
```

The command searches the codebase for `TODO` and `TASK`, then creates one built-in task for each
match. Each task records the original comment, absolute file path, line number, and nearby code.

The sweep command does not define deduplication or path-exclusion rules. Review the resulting task
list when generated files, vendored code, repeated comments, or previously captured comments may be
present.

## Implement Tasks

### One Task

```text
/builtin-tasks:do-one-task
```

The command selects the pending, unblocked task with the lowest ID, marks it in progress, and
implements only that task. It runs task-specific validation followed by
`/orchestration:finish`, which creates the task commit and validates the committed state. The task
is marked completed only after the finish workflow succeeds.

Blocked tasks are not selected. If the queue contains no pending, unblocked task, the command has
nothing to implement.

### Sequential Batch

```text
/builtin-tasks:do-all-tasks
```

The batch command repeatedly launches the plugin's `do-task` agent for the next pending, unblocked
task. Each agent finishes and commits its task before another task starts. After every agent
returns, the coordinator checks the committed `HEAD` with `git-test`; it stops instead of stacking
more work if the result is bad or unknown.

You can append instructions that limit the run:

```text
/builtin-tasks:do-all-tasks Stop after the parser-related tasks
```

Without extra instructions, the loop continues until no incomplete task remains. A task is
attempted at most once during a batch run; a failed task is skipped for the rest of that run so the
loop cannot retry it indefinitely.

### Team Batch

```text
/builtin-tasks:do-all-with-team
```

The team command reviews pending tasks and their dependencies, creates a Claude Code team, mirrors
the pending work into the team's task list, and assigns work to members. It monitors assignments,
reassigns work as members become available, shuts down the members, and deletes the team after the
run.

Coordination is part of this workflow:

- Every task must produce exactly one commit before its member receives more work.
- Tasks that modify the same files must not run concurrently.
- The lead may serialize overlapping work or place it in separate Git worktrees.
- Whenever all members are idle, the shared checkout must have no uncommitted changes.

Optional instructions can constrain the team run in the same way as the sequential command:

```text
/builtin-tasks:do-all-with-team Process only tasks that do not touch the database schema
```

Parallel execution is not useful when most tasks share files or require earlier tasks to finish.
Use `/builtin-tasks:do-all-tasks` for those queues.

## Operational Boundaries

- The built-in task list, not `.llm/todo.md`, is the source of queue state.
- Single and sequential execution select pending tasks that are not blocked; dependency state can
  therefore prevent a task from becoming available.
- Implementation changes are committed task by task and may be rebased by the finish workflow.
- A failed or unavailable `git-test` result stops sequential processing at the current `HEAD`.
- Plan import creates tasks but does not implement them; the sweep command creates tasks but does
  not resolve or remove the source comments.
- Team execution coordinates dependencies and overlapping files, but it does not make coupled tasks
  safe to run in parallel.
