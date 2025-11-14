# Claude Code Plugins

Collection of plugins for Claude Code that enhance terminal integration and task management.

## Available Plugins

- **[markdown-tasks](plugins/markdown-tasks/README.md)** - Keep your tasks in a simple markdown file (`todo.md`) and let Claude Code implement them automatically
- **[git-worktree](plugins/git-worktree/README.md)** - Git worktree management utilities
- **[tmux-titles](plugins/tmux-titles/README.md)** - tmux terminal integration with window title updates and status indicators
- **[iterm2-titles](plugins/iterm2-titles/README.md)** - iTerm2 terminal integration with status indicators

## Installation

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install markdown-tasks@motlin-claude-code-plugins
claude plugin install git-worktree@motlin-claude-code-plugins
claude plugin install tmux-titles@motlin-claude-code-plugins
claude plugin install iterm2-titles@motlin-claude-code-plugins
```

Or run [`install.sh`](install.sh):

```bash
curl -fsSL https://raw.githubusercontent.com/motlin/claude-code-plugins/main/install.sh | bash
```

