# markdown-tasks Plugin

A task queue in `.llm/todo.md`, managed through bundled Python scripts, for Claude Code and Codex.

- `/markdown-tasks:add-one-task` (command) / `markdown-tasks:markdown-add-task`: add one self-contained task
- `markdown-tasks:plan-tasks`: turn a planning conversation into tasks
- `markdown-tasks:import-plan`: turn a plan file into one task per step
- `markdown-tasks:sweep-todos`: add source `TODO` comments as tasks
- `markdown-tasks:do-one-task`: implement and commit the next task
- `markdown-tasks:do-all-tasks`: run one fresh `do-task` worker per task until the queue is empty
- `markdown-tasks:markdown-unblock-tasks`: recover blocked `[!]` tasks from archives
- `markdown-tasks:tasks`: task format and script reference shared by the other skills

Executing tasks needs the `orchestration`, `build`, `git`, and `code` plugins, and `git-test` configured in the repository (see `build:test-setup`).
