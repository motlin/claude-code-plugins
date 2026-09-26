# Claude Code and Codex Plugins

Plugins for agent workflows, development tools, terminal feedback, and safety checks.

## Plugin Catalog

`✅` means the plugin installs on that product; `—` means it does not.

### Plan and Run Work

| Plugin                                             | Use it to                                     | Claude Code | Codex |
| -------------------------------------------------- | --------------------------------------------- | ----------- | ----- |
| [markdown-tasks](plugins/markdown-tasks/README.md) | Manage a visible task queue in `.llm/todo.md` | ✅          | ✅    |

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

| Plugin                                                                                    | Use it to                                                        | Claude Code | Codex |
| ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ----------- | ----- |
| [demo](plugins/demo/README.md)                                                            | Demo real IO — wire, SQL, DDL, commands — captured, not authored | ✅          | ✅    |
| [investigation-report](plugins/investigation-report/skills/investigation-report/SKILL.md) | Turn terminal investigations into explanatory HTML reports       | ✅          | ✅    |
| [orchestration](plugins/orchestration/README.md)                                          | Coordinate shared conversation, testing, and finish conventions  | ✅          | ✅    |
| [plugin-and-skill-dev](plugins/plugin-and-skill-dev/README.md)                            | Write durable skills, agents, and commands                       | ✅          | ✅    |
| [recap](plugins/recap/README.md)                                                          | End responses with the request recap and most relevant link      | ✅          | ✅    |

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
| [herdr-reboot](plugins/herdr-reboot/)              | Snapshot and restore agent sessions across herdr restarts       | ✅          | ✅    |
| `herdr-titles`                                     | Report Claude sessions and sync custom titles to Herdr          | ✅          | —     |
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

From a local checkout (the default with no argument):

```bash
./install-local.sh claude
```

### Codex

Install a plugin marked `✅` in the Codex column:

```bash
codex plugin marketplace add motlin/claude-code-plugins
codex plugin add markdown-tasks@motlin-claude-code-plugins
```

From a local checkout:

```bash
./install-local.sh codex
```

`./install-local.sh all` installs both. After editing a plugin locally, refresh its Codex
installation before starting a new conversation:

```bash
just codex-reinstall --plugin markdown-tasks
```

## Install Skills Without a Plugin

The [`skills`](https://github.com/vercel-labs/skills) CLI installs individual skills:

```bash
npx skills add motlin/claude-code-plugins --list
npx skills add motlin/claude-code-plugins --skill markdown-tasks --agent codex
npx skills add motlin/claude-code-plugins --skill markdown-tasks --agent claude-code
```

From a local checkout, use `.` as the repository. This installs skills only, not hooks,
commands, or agents.
