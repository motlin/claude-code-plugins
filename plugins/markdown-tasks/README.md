# markdown-tasks Plugin

`markdown-tasks` manages a repository-local queue in `.llm/todo.md`. Tasks are ordinary Markdown
checkboxes, while bundled scripts give agents a narrow view of one item at a time. The plugin works
with Claude Code and Codex.

Choose this plugin when you want inspectable task state, a queue scoped to the current checkout, or
the same task model in both products. Choose [builtin-tasks](../builtin-tasks/README.md) when Claude
Code's built-in dependency tracking and team execution should own the queue.

## Install

### Claude Code

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install markdown-tasks@motlin-claude-code-plugins
```

### Codex

```bash
codex plugin marketplace add motlin/claude-code-plugins
codex plugin add markdown-tasks@motlin-claude-code-plugins
```

The helper scripts run with Python. Task implementation also uses this repository's finish workflow,
so install `orchestration`, `build`, `git`, and `code` from the same marketplace and configure
`git-test` in repositories where tasks will be executed.

Keep `.llm/` out of version control when the queue is local agent context. Each Git worktree then
has an independent task file.

## Choose a Workflow

Claude Code exposes slash commands and Codex exposes corresponding skills:

| Goal                           | Claude Code command                  | Codex skill                             |
| ------------------------------ | ------------------------------------ | --------------------------------------- |
| Add one task                   | `/markdown-tasks:add-one-task`       | `$markdown-tasks:markdown-add-task`     |
| Capture the current planning   | `/markdown-tasks:plan-tasks`         | `$markdown-tasks:markdown-plan-tasks`   |
| Import a plan file             | `/markdown-tasks:import-plan <path>` | `$markdown-tasks:markdown-import-plan`  |
| Collect source `TODO` comments | `/markdown-tasks:sweep-todos`        | `$markdown-tasks:markdown-sweep-todos`  |
| Implement the next task        | `/markdown-tasks:do-one-task`        | `$markdown-tasks:markdown-do-one-task`  |
| Process every incomplete task  | `/markdown-tasks:do-all-tasks`       | `$markdown-tasks:markdown-do-all-tasks` |

The `markdown-tasks:tasks` skill supplies the low-level task format and script conventions used by
the workflow skills. It is not normally the entry point for a queue operation.

## Task File

The scripts create `.llm/todo.md` on the first add operation. A task begins with one of these
markers:

- `[ ]` is ready.
- `[x]` completed validation and was committed.
- `[!]` failed during a batch attempt and is skipped.

Indent context beneath the checkbox so extraction returns the whole task:

```markdown
- [ ] Require authentication on API routes.
      Update `/workspace/project/src/routes/api.ts`.
      Reuse `validateJwt` from `/workspace/project/src/auth/tokens.ts`.
      Return 401 before invoking a protected route when validation fails.
```

Every item should stand alone. Include absolute paths, named code elements, dependencies, examples
to follow, and the expected result. Workers receive the first incomplete task and its indented
context, not the rest of the queue.

The bundled scripts are the supported way for agents to change the task file:

| Script            | Operation                                             |
| ----------------- | ----------------------------------------------------- |
| `task_add.py`     | Append a self-contained `[ ]` task                    |
| `task_get.py`     | Print the first incomplete task and its context       |
| `task_mark.py`    | Mark the first incomplete task `[x]` or another state |
| `task_archive.py` | Move a finished queue to `.llm/YYYY-MM-DD-todo.md`    |

## Populate the Queue

`add-one-task` expands one description into a self-contained item. `plan-tasks` converts the
requirements already discussed in the conversation into a batch and writes that batch in one
operation.

`import-plan` takes a stored plan, places it under `.llm/plans/`, and creates tasks for its steps.
The generated queue also contains a whole-plan verification task and a final task that archives the
plan under `.llm/plans/done/`.

`sweep-todos` searches for `TODO` comments and adds their paths, line numbers, and text to the
queue. It captures work; it does not remove comments or implement them.

## Execute the Queue

`do-one-task` extracts one `[ ]` item, implements only that item, runs task-specific validation,
and invokes the finish pipeline. The task is marked `[x]` only after its commit and validation
succeed.

`do-all-tasks` is a sequential coordinator. It starts one fresh worker per task, requires one clean
task commit, and checks `HEAD` before extracting the next item. A failed worker leaves no commit;
the coordinator marks that task `[!]` and continues. Ambiguous task state or an unverified commit
stops the run instead of stacking more work.

When no `[ ]` items remain, the all-tasks workflow archives the queue to a dated file. To retry a
blocked item later, change its marker from `[!]` back to `[ ]` before starting another run.

## Boundaries

- The first `[ ]` item is the next item; the format has no built-in dependency graph or priority
  field.
- Batch execution is sequential because every worker shares the same checkout and task file.
- The task list is not committed automatically. Its persistence and visibility follow how the
  repository treats `.llm/`.
- Plan and comment workflows create queue entries but do not guarantee that their source material
  is complete or deduplicated.
- Implementation depends on the finish pipeline and stops when the committed `HEAD` cannot be
  verified.
