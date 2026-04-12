# Claude Code Plugins

A collection of 19 plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that add task management, git workflow automation, terminal status indicators, build tooling, and more.

## Quick Start

```bash
# Add the marketplace
claude plugin marketplace add motlin/claude-code-plugins

# Install the plugins you want
claude plugin install markdown-tasks@motlin-claude-code-plugins
claude plugin install git@motlin-claude-code-plugins
claude plugin install build@motlin-claude-code-plugins
```

Each plugin is independent — install only what you need.

## Plugins

### Task Management

| Plugin                                                 | Description                                                                                                                                                                                                                        |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[markdown-tasks](plugins/markdown-tasks/README.md)** | Manage tasks in a markdown checklist (`.llm/todo.md`). Subagents implement tasks one at a time, keeping Claude Code busy for hours without context overflow. Commands: `/do-all-tasks`, `/add-one-task`, `/sweep-todos`, and more. |
| **[builtin-tasks](plugins/builtin-tasks)**             | Alternative task runner using Claude Code's built-in task tools. Supports parallel execution with `/do-all-with-team`.                                                                                                             |

### Git & GitHub

| Plugin                                 | Description                                                                                                                                                                               |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[git](plugins/git/README.md)**       | Smart commits, conflict resolution, rebase management, worktree creation, and branch splitting. Commands: `/commit`, `/conflicts`, `/rebase-all`, `/worktree`, `/split-branch`, and more. |
| **[git-guards](plugins/git-guards)**   | Hook that blocks dangerous git commands (`git add -A`, force push to main, `reset --hard`, `clean -fd`) before they execute.                                                              |
| **[github](plugins/github/README.md)** | Fetches failing GitHub Actions checks, analyzes the logs, fixes the issue, and creates a fixup commit. Command: `/gha`.                                                                   |

### Terminal Status Indicators

These plugins update your terminal tab/window title to show what Claude Code is doing: `✻` working, `✓` done, `?` waiting for input, `$` running a shell command, `✎` editing a file.

| Plugin                                                 | Description                                                                                                              |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| **[tmux-titles](plugins/tmux-titles/README.md)**       | Status indicators in tmux window titles. Integrates with `window-status-format` via the `@claude_indicator` user option. |
| **[iterm2-titles](plugins/iterm2-titles/README.md)**   | Status indicators in iTerm2 tab titles.                                                                                  |
| **[ghostty-titles](plugins/ghostty-titles/README.md)** | Status indicators in Ghostty tab titles.                                                                                 |

### Build & Code Quality

| Plugin                               | Description                                                                                                                                                                  |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[build](plugins/build/README.md)** | Test every commit on a branch and loop until they all pass. Auto-fixes with `git commit --fixup` and `rebase --autosquash`. Commands: `/test-branch`, `/fix`, `/dev-server`. |
| **[code](plugins/code/README.md)**   | Remove redundant comments, add emoji to content, enforce `@formatter:off` guards in code generators. Commands: `/comments`, `/strict-tests`, `/formatter-off`.               |

### Notifications & Dashboard

| Plugin                                             | Description                                                                                                                                                   |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[pushover](plugins/pushover/README.md)**         | Get phone notifications via [Pushover](https://pushover.net/) when Claude Code needs your attention (permission prompts, questions). Requires `woof` in PATH. |
| **[claude-code-plans](plugins/claude-code-plans)** | Send session lifecycle events to the [claude-code-plans](https://github.com/qualint/claude-code-plans) dashboard on `localhost:8899`.                         |

### Environment & Workflow

| Plugin                                                                       | Description                                                                                                                                                    |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[orchestration](plugins/orchestration/README.md)**                         | Core skills for conversation style, code quality, and workflow automation. Coordinates other plugins and ensures the finish pipeline runs before sessions end. |
| **[worktree-setup](plugins/worktree-setup/README.md)**                       | Automatically copies gitignored files and runs `direnv allow`/`mise trust` when Claude Code creates an agent worktree.                                         |
| **[offline-claude-code-guide](plugins/offline-claude-code-guide/README.md)** | Offline fallback for Claude Code documentation when the built-in guide subagent fails due to network issues.                                                   |

### Language & Tool Specific

| Plugin                                     | Description                                                                                   |
| ------------------------------------------ | --------------------------------------------------------------------------------------------- |
| **[java](plugins/java/README.md)**         | OpenRewrite recipe development, Maven POM dependency ordering, and Liquibase lock resolution. |
| **[justfile](plugins/justfile/README.md)** | Style guidelines and doc comment optimization for justfiles.                                  |
| **[temporal-data](plugins/temporal-data)** | Skills for system-time versioned tables and temporal caching patterns.                        |

### Plugin Development

| Plugin                                                             | Description                                                               |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| **[plugin-and-skill-dev](plugins/plugin-and-skill-dev/README.md)** | Guidelines for writing stable, maintainable skills, agents, and commands. |

## Installation

### Add the Marketplace

From GitHub:

```bash
claude plugin marketplace add motlin/claude-code-plugins
```

For local development, clone first and add from the local directory:

```bash
git clone https://github.com/motlin/claude-code-plugins.git
cd claude-code-plugins
claude plugin marketplace add "$(pwd)"
```

### Install Plugins

Install any combination:

```bash
claude plugin install markdown-tasks@motlin-claude-code-plugins
claude plugin install git@motlin-claude-code-plugins
claude plugin install git-guards@motlin-claude-code-plugins
claude plugin install build@motlin-claude-code-plugins
claude plugin install code@motlin-claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
claude plugin install iterm2-titles@motlin-claude-code-plugins
claude plugin install ghostty-titles@motlin-claude-code-plugins
claude plugin install pushover@motlin-claude-code-plugins
claude plugin install worktree-setup@motlin-claude-code-plugins
claude plugin install orchestration@motlin-claude-code-plugins
claude plugin install github@motlin-claude-code-plugins
claude plugin install builtin-tasks@motlin-claude-code-plugins
claude plugin install java@motlin-claude-code-plugins
claude plugin install justfile@motlin-claude-code-plugins
claude plugin install temporal-data@motlin-claude-code-plugins
claude plugin install offline-claude-code-guide@motlin-claude-code-plugins
claude plugin install claude-code-plans@motlin-claude-code-plugins
claude plugin install plugin-and-skill-dev@motlin-claude-code-plugins
```

## License

Apache-2.0
