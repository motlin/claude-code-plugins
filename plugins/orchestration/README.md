# Orchestration Plugin

Core workflow orchestration for Claude Code. The main feature is the **finish pipeline** — a mandatory sequence that runs before every session ends, ensuring code is built, committed, rebased, simplified, and verified.

## The Finish Pipeline

The `/orchestration:finish` skill spawns the `orchestration:finish` agent, which runs a six-step pipeline after every task:

```
commit → precommit → rebase → simplify → fixup commit → precommit again
```

Every step is mandatory. Even documentation-only changes go through the full pipeline because the precommit step includes markdown formatters.

### The Steps

**Step 1: Commit** — Runs the `git:commit-handler` agent. Stages files individually (never `git add .`), generates a commit message starting with a present-tense verb, and runs the commit. If pre-commit hooks modify files, it re-stages and retries. Commit runs first because `git test run HEAD` refuses to run on a dirty tree and tests the committed HEAD, not the working tree.

**Step 2: Precommit** — Runs the `build:precommit-runner` agent, which executes `git test run HEAD` on the now-clean tree. This runs whatever build command is configured for the repo (typically formatting, linting, and tests). Results are cached per commit, so re-running on an already-passing commit is instant.

**Step 3: Rebase** — Runs the `git:rebaser` agent. Fetches the upstream branch and rebases on top of it. If there are merge conflicts, delegates to the `git:conflict-resolver` agent.

**Step 4: Simplify** — Delegates to the `code-simplifier:code-simplifier` agent, which reviews the diff for reuse, quality, and efficiency.

**Step 5: Fixup commit** — Stages any changes from the simplify step and creates a `git commit --fixup=HEAD` so the simplification gets folded into the original commit on the next rebase.

**Step 6: Precommit again** — Runs the precommit agent one more time to verify that the simplify changes pass all checks.

## Stop Hooks (in other plugins)

The dirty-tree and test-result checks that trigger the finish pipeline live in the plugins that own those concerns:

- **[git](../git/README.md)** — `Stop` hook warns about unstaged changes, staged uncommitted changes, and untracked files
- **[build](../build/README.md)** — `Stop` hook warns about missing `git test` results for HEAD (skipped on battery power)

## Skills

### `orchestration:orchestration`

The startup skill. Provides guidelines for:

- Which skills to invoke for different task types (code quality, CLI, git, etc.)
- Delegating git operations to specialized agents (never run `git commit` directly)
- Writing temporary files to `.llm/` instead of `/tmp`
- Always running `/orchestration:finish` before returning control to the user

### `orchestration:conversation-style`

Response formatting guidelines.

### `orchestration:llm-context`

Guidelines for working with `.llm/` directories.

### `orchestration:finish`

The finish pipeline described above.

## Setup

After installing, add to your `~/.claude/CLAUDE.md`:

```markdown
Always use the @orchestration:orchestration skill for core guidelines and workflow automation.
```

## Dependencies

The finish pipeline delegates to agents from other plugins:

- **[build](../build/README.md)** — `precommit-runner` agent
- **[git](../git/README.md)** — `commit-handler`, `rebaser`, and `conflict-resolver` agents
- **[code-simplifier](https://github.com/anthropics/claude-code-plugins)** — `code-simplifier:code-simplifier` agent

Install these plugins alongside orchestration for the full pipeline.

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install orchestration@motlin-claude-code-plugins
claude plugin install build@motlin-claude-code-plugins
claude plugin install git@motlin-claude-code-plugins
claude plugin install code@motlin-claude-code-plugins
```
