# Claude Code and Codex Plugins

This repository distributes focused plugins for agent workflows, development tools, terminal
feedback, and safety checks. Install a plugin through the Claude Code or Codex marketplace when
you need its full package of skills, hooks, commands, or agents.

## Plugin Catalog

The catalog follows the checked-in marketplace and plugin manifests. `✅` means the marketplace
allows installation for that product; `—` means it does not.

### Plan and Run Work

| Plugin                                             | Use it to                                                         | Claude Code | Codex |
| -------------------------------------------------- | ----------------------------------------------------------------- | ----------- | ----- |
| [builtin-tasks](plugins/builtin-tasks/README.md)   | Run task queues with Claude Code's task, dependency, and team API | ✅          | —     |
| [markdown-tasks](plugins/markdown-tasks/README.md) | Manage a visible task queue in `.llm/todo.md`                     | ✅          | ✅    |

### Build and Maintain Code

| Plugin                                             | Use it to                                                        | Claude Code | Codex |
| -------------------------------------------------- | ---------------------------------------------------------------- | ----------- | ----- |
| [build](plugins/build/README.md)                   | Run precommit checks and test commits or branches                | ✅          | ✅    |
| [code](plugins/code/README.md)                     | Apply code-quality, comment, CLI, and test-writing conventions   | ✅          | ✅    |
| [git](plugins/git/README.md)                       | Commit, rebase, resolve conflicts, and manage branches/worktrees | ✅          | ✅    |
| [github](plugins/github/README.md)                 | Diagnose GitHub Actions failures                                 | ✅          | ✅    |
| [justfile](plugins/justfile/README.md)             | Write and tighten Justfile recipe documentation                  | ✅          | ✅    |
| [worktree-setup](plugins/worktree-setup/README.md) | Prepare files and tools in Claude Code agent worktrees           | ✅          | —     |

### Guide Agents and Authors

| Plugin                                                                                    | Use it to                                                       | Claude Code | Codex |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ----------- | ----- |
| [investigation-report](plugins/investigation-report/skills/investigation-report/SKILL.md) | Turn terminal investigations into explanatory HTML reports      | ✅          | ✅    |
| [orchestration](plugins/orchestration/README.md)                                          | Coordinate shared conversation, testing, and finish conventions | ✅          | ✅    |
| [plugin-and-skill-dev](plugins/plugin-and-skill-dev/README.md)                            | Write durable skills, agents, and commands                      | ✅          | ✅    |
| [recap](plugins/recap/README.md)                                                          | End responses with the request recap and most relevant link     | ✅          | ✅    |

### Protect the Session

| Plugin                                                   | Use it to                                               | Claude Code | Codex |
| -------------------------------------------------------- | ------------------------------------------------------- | ----------- | ----- |
| [bash-guards](plugins/bash-guards/README.md)             | Reject destructive shell commands before execution      | ✅          | ✅    |
| [git-guards](plugins/git-guards/)                        | Reject destructive Git commands before execution        | ✅          | ✅    |
| [stop-phrase-guard](plugins/stop-phrase-guard/README.md) | Keep the agent working after premature stopping phrases | ✅          | ✅    |

### Track Sessions and Terminal Activity

| Plugin                                             | Use it to                                                       | Claude Code | Codex |
| -------------------------------------------------- | --------------------------------------------------------------- | ----------- | ----- |
| [claude-code-plans](plugins/claude-code-plans/)    | Publish session lifecycle events to a claude-code-plans service | ✅          | ✅    |
| [ghostty-titles](plugins/ghostty-titles/README.md) | Show agent activity in a Ghostty tab title                      | ✅          | ✅    |
| `herdr-titles`                                     | Report Claude sessions and sync custom titles to Herdr          | ✅          | —     |
| [iterm2-titles](plugins/iterm2-titles/README.md)   | Show agent activity in an iTerm2 window title                   | ✅          | ✅    |
| [tmux-reboot](plugins/tmux-reboot/)                | Snapshot and restore agent sessions across tmux restarts        | ✅          | ✅    |
| [tmux-titles](plugins/tmux-titles/README.md)       | Show agent activity in the tmux window status                   | ✅          | ✅    |

### Work with Specialized Technologies

| Plugin                                                               | Use it to                                                 | Claude Code | Codex |
| -------------------------------------------------------------------- | --------------------------------------------------------- | ----------- | ----- |
| [java](plugins/java/README.md)                                       | Work with Maven, OpenRewrite, Liquibase, and POM ordering | ✅          | ✅    |
| [temporal-data](plugins/temporal-data/skills/temporal-data/SKILL.md) | Design and cache system-time temporal data                | ✅          | ✅    |

## Install Plugins

### Claude Code

Register this repository once, then install the plugin you want:

```bash
claude plugin marketplace add motlin/claude-code-plugins
claude plugin install markdown-tasks@motlin-claude-code-plugins
```

To install the Claude Code variants from a local checkout:

```bash
./install-local.sh claude
```

Running `./install-local.sh` without an argument also selects Claude Code.

### Codex

Add the marketplace, then install a plugin marked `✅` in the Codex column:

```bash
codex plugin marketplace add motlin/claude-code-plugins
codex plugin add markdown-tasks@motlin-claude-code-plugins
```

To install all compatible Codex plugins from a local checkout:

```bash
./install-local.sh codex
```

Use `./install-local.sh all` to install both product variants. When developing a plugin locally,
refresh its Codex installation before starting a new conversation:

```bash
just codex-reinstall markdown-tasks
```

## Install Skills Without a Plugin

The open [`skills`](https://github.com/vercel-labs/skills) CLI can list the Agent Skills in this
repository and install one for a specific agent:

```bash
npx skills add motlin/claude-code-plugins --list
npx skills add motlin/claude-code-plugins --skill markdown-tasks --agent codex
npx skills add motlin/claude-code-plugins --skill markdown-tasks --agent claude-code
```

From a local checkout, replace the repository name with `.`. This route installs skill
instructions and bundled resources only; use a product marketplace when the plugin also relies on
hooks, commands, or custom agents.
