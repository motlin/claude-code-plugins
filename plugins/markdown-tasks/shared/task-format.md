# Task Format Reference

The task list is in `.llm/todo.md`.

NEVER use the `Read` tool on `.llm/todo.md`. Always interact with the task list exclusively through the Python scripts in this Skill.

## Task States

- `[ ]` - Not started (ready to work on)
- `[x]` - Completed
- `[!]` - Blocked after failed attempt

## Task Structure

Each task includes indented context lines with full implementation details:

- Absolute file paths
- Exact function/class names
- Code analogies to existing patterns
- Dependencies and prerequisites
- Expected outcomes

## Task List Location

The task list is always at `<repository-root>/.llm/todo.md`. The `.llm/` directory is gitignored via `.git/info/exclude`.

## Standalone Context

Each task is extracted and executed in isolation. The `task_get.py` script extracts only one task at a time - it cannot see other tasks in the file. Therefore:

1. Every task must contain ALL context needed to implement it
2. Repeat shared context in every related task - if 5 tasks share the same background, repeat it 5 times
3. Never reference other tasks - phrases like "similar to task above" are useless
4. Include the full picture - source of inspiration, files involved, patterns to follow

When adding multiple related tasks (e.g., from a feature comparison table), each task must independently contain:

- The source/inspiration (e.g., "Adopting pattern from typescript-template repo")
- Specific files to modify or create
- Implementation details and patterns to follow
- Any prerequisites or dependencies

## Example: Bad vs Good Task Lists

Bad - Relies on shared context that won't be visible:

```markdown
# Adopting features from typescript-template

- [ ] Add auto-fix jobs
- [ ] Add pre-commit CI job
- [ ] Add ESLint annotations
```

Good - Each task is completely self-contained:

```markdown
- [ ] Add auto-fix jobs to pull-request.yml
  - Adopting feature from typescript-template repository
  - File: `.github/workflows/pull-request.yml`
  - Add jobs: eslint-fix, biome-format-fix, prettier-fix
  - These jobs auto-push formatting fixes to PR branches
  - Reference: typescript-template/.github/workflows/pull-request.yml

- [ ] Add pre-commit CI job to merge-group.yml
  - Adopting feature from typescript-template repository
  - File: `.github/workflows/merge-group.yml`
  - Use pre-commit/action to run hooks in CI
  - Reference: typescript-template/.github/workflows/merge-group.yml

- [ ] Add ESLint annotations to show lint errors inline on PRs
  - Adopting feature from typescript-template repository
  - File: `.github/workflows/pull-request.yml`
  - Use ataylorme/eslint-annotate-action
  - Reference: typescript-template/.github/workflows/pull-request.yml
```
