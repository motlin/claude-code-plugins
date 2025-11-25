# Claude Code Plugins

Collection of plugins for Claude Code that enhance terminal integration and task management.

## Available Plugins

- **[orchestration](plugins/orchestration/README.md)** - Core orchestration guidelines for conversation style, code style, testing, tool conventions, and workflow automation
- **[markdown-tasks](plugins/markdown-tasks/README.md)** - Keep your tasks in a simple markdown file (`todo.md`) and let Claude Code implement them automatically
- **[tmux-titles](plugins/tmux-titles/README.md)** - tmux terminal integration with window title updates and status indicators
- **[iterm2-titles](plugins/iterm2-titles/README.md)** - iTerm2 terminal integration with status indicators
- **[build](plugins/build/README.md)** - Test and build automation tools that loop until all commits pass
- **[code](plugins/code/README.md)** - Code quality tools for comment cleanup and emoji enhancement
- **[git](plugins/git/README.md)** - Git workflow automation with smart commits, conflict resolution, rebase management, worktree creation, and worktree cleanup
- **[github](plugins/github/README.md)** - GitHub Actions troubleshooting and CI/CD automation
- **[java](plugins/java/README.md)** - Java and Maven tools for OpenRewrite import ordering and POM dependency management
- **[justfile](plugins/justfile/README.md)** - Utilities for working with justfiles, including doc comment optimization

## Installation

### 1. Add the Marketplace

From GitHub:

```bash
claude plugin marketplace add motlin/claude-code-plugins
```

For local development or if you are behind a firewall, clone first and add from a local directory:

```bash
claude plugin marketplace add "$(pwd)"
```

### 2. Install the Plugins

```bash
claude plugin install markdown-tasks@motlin-claude-code-plugins
claude plugin install orchestration@motlin-claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
claude plugin install iterm2-titles@motlin-claude-code-plugins
claude plugin install build@motlin-claude-code-plugins
claude plugin install code@motlin-claude-code-plugins
claude plugin install git@motlin-claude-code-plugins
claude plugin install github@motlin-claude-code-plugins
claude plugin install java@motlin-claude-code-plugins
claude plugin install justfile@motlin-claude-code-plugins
```
