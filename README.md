# Claude Code Plugins

Collection of plugins for Claude Code that enhance terminal integration and task management.

## Available Plugins

- **[markdown-tasks](plugins/markdown-tasks/README.md)** - Keep your tasks in a simple markdown file (`todo.md`) and let Claude Code implement them automatically
- **[git-worktree](plugins/git-worktree/README.md)** - Git worktree management utilities
- **[tmux-titles](plugins/tmux-titles/README.md)** - tmux terminal integration with window title updates and status indicators
- **[iterm2-titles](plugins/iterm2-titles/README.md)** - iTerm2 terminal integration with status indicators
- **[build](plugins/build/README.md)** - Test and build automation tools that loop until all commits pass
- **[code-quality](plugins/code-quality/README.md)** - Code quality tools for comment cleanup and emoji enhancement
- **[git-workflow](plugins/git-workflow/README.md)** - Git workflow automation with smart commits, conflict resolution, rebase management, and worktree cleanup
- **[java-maven](plugins/java-maven/README.md)** - Java and Maven tools for OpenRewrite import ordering and POM dependency management
- **[justfile-utils](plugins/justfile-utils/README.md)** - Utilities for working with justfiles, including doc comment optimization

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install markdown-tasks@motlin-claude-code-plugins
claude plugin install git-worktree@motlin-claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
claude plugin install iterm2-titles@motlin-claude-code-plugins
claude plugin install build@motlin-claude-code-plugins
claude plugin install code-quality@motlin-claude-code-plugins
claude plugin install git-workflow@motlin-claude-code-plugins
claude plugin install java-maven@motlin-claude-code-plugins
claude plugin install justfile-utils@motlin-claude-code-plugins
```

Or run [`install.sh`](install.sh):

```bash
curl -fsSL https://raw.githubusercontent.com/motlin/claude-code-plugins/main/install.sh | bash
```

If you are behind a proxy, you can install the marketplace from a directory.

```bash
git clone https://github.com/motlin/claude-code-plugins.git/ ~/.claude/plugins/marketplaces/motlin-claude-code-plugins
claude plugin marketplace add ~/.claude/plugins/marketplaces/motlin-claude-code-plugins
claude plugin install markdown-tasks@motlin-claude-code-plugins
claude plugin install git-worktree@motlin-claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
claude plugin install iterm2-titles@motlin-claude-code-plugins
claude plugin install build@motlin-claude-code-plugins
claude plugin install code-quality@motlin-claude-code-plugins
claude plugin install git-workflow@motlin-claude-code-plugins
claude plugin install java-maven@motlin-claude-code-plugins
claude plugin install justfile-utils@motlin-claude-code-plugins
```

