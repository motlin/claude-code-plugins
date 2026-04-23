# Orchestration Plugin

Core workflow orchestration for Claude Code. The main feature is the **finish pipeline** — a mandatory sequence that runs before every session ends, ensuring code is built, committed, rebased, simplified, and verified.

## The Finish Pipeline

The `/orchestration:finish` skill runs a six-step pipeline after every task:

```
precommit → commit → rebase → simplify → fixup commit → precommit again
```

Every step is mandatory. Even documentation-only changes go through the full pipeline because the precommit step includes markdown formatters.

### The Steps

**Step 1: Precommit** — Runs the `build:precommit-runner` agent, which executes `git test run`. This runs whatever build command is configured for the repo (typically formatting, linting, and tests). Results are cached per commit, so re-running on an already-passing commit is instant.

**Step 2: Commit** — Runs the `git:commit-handler` agent. Stages files individually (never `git add .`), generates a commit message starting with a present-tense verb, and runs the commit. If pre-commit hooks modify files, it re-stages and retries.

**Step 3: Rebase** — Runs the `git:rebaser` agent. Fetches the upstream branch and rebases on top of it. If there are merge conflicts, delegates to the `git:conflict-resolver` agent.

**Step 4: Simplify** — Spawns the `code-simplifier:code-simplifier` subagent, which reviews the diff for reuse, quality, and efficiency.

**Step 5: Fixup commit** — Stages any changes from the simplify step and creates a `git commit --fixup=HEAD` so the simplification gets folded into the original commit on the next rebase.

**Step 6: Precommit again** — Runs the precommit agent one more time to verify that the simplify changes pass all checks.

## The Stop Hook

A `Stop` hook runs `check-finish-ran.sh` every time Claude Code tries to end a session. The script checks for:

- Unstaged changes in the working tree
- Staged but uncommitted changes
- Untracked files
- Missing `git test` results for HEAD

If any of these are true, the hook fails with exit code 2 and tells Claude Code to read `finish-not-run.md`, which instructs it to run `/orchestration:finish`. This creates a retry loop — Claude Code can't end the session until the repo is clean.

The hook allows up to 3 retry attempts before giving up, to avoid infinite loops. A `.llm/skip-finish-check` file can break the loop in edge cases, but the finish skill won't create it on the first attempt.

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
# 🤖 Instructions for LLMs

Always use the @orchestration:orchestration skill for core guidelines and workflow automation.
```
