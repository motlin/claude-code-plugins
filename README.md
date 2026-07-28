# Claude Code and Codex Plugins

This marketplace packages task queues, terminal status hooks, and development workflows for Claude
Code and Codex. Install a complete plugin when you need its hooks, commands, agents, and skills;
install an individual [Agent Skill](https://agentskills.io/) when its instructions are sufficient.

## Choose a Task Workflow

The repository includes two task plugins with different sources of truth:

| Plugin                                             | Task state                       | Claude Code | Codex     | Best fit                                                     |
| -------------------------------------------------- | -------------------------------- | ----------- | --------- | ------------------------------------------------------------ |
| [builtin-tasks](plugins/builtin-tasks/README.md)   | Claude Code's built-in task list | Available   | —         | Claude-only queues, dependencies, and parallel team runs     |
| [markdown-tasks](plugins/markdown-tasks/README.md) | `.llm/todo.md` checkboxes        | Available   | Available | Visible, repository-local queues and sequential task commits |

Both plugins can import plans, collect source comments, and give each implementation task its own
commit. Choose `builtin-tasks` when Claude Code's task and team tools should own the queue. Choose
`markdown-tasks` when the queue should be a plain file or the workflow must also run in Codex.

## Choose a Terminal Title Plugin

The title plugins turn hook events into a compact activity indicator. Install the one that owns the
surface you want to update:

| Plugin                                             | Display target                  | Extra setup                                   |
| -------------------------------------------------- | ------------------------------- | --------------------------------------------- |
| [tmux-titles](plugins/tmux-titles/README.md)       | tmux window status              | Add `@claude_indicator` to tmux status format |
| [iterm2-titles](plugins/iterm2-titles/README.md)   | iTerm2 window title             | Optional shell or AutoLaunch cleanup          |
| [ghostty-titles](plugins/ghostty-titles/README.md) | Ghostty tab title through OSC 0 | None beyond `jq`                              |

All three are available to Claude Code and Codex. Their shared manifests cover prompt, tool,
compaction, stop, and session-start activity. Claude Code loads an additional hook manifest for
events that are not shared by both products.

## Plugin Catalog

The compatibility columns below follow the current Claude Code and Codex marketplace manifests.
An em dash means the plugin remains in the Codex catalog for marketplace parity but its
installation policy is `NOT_AVAILABLE`.

| Plugin                                                         | Purpose                                              | Claude Code | Codex     |
| -------------------------------------------------------------- | ---------------------------------------------------- | ----------- | --------- |
| [markdown-tasks](plugins/markdown-tasks/README.md)             | Markdown-backed task planning and execution          | Available   | Available |
| [tmux-titles](plugins/tmux-titles/README.md)                   | tmux activity indicators and window naming           | Available   | Available |
| [iterm2-titles](plugins/iterm2-titles/README.md)               | iTerm2 activity titles                               | Available   | Available |
| [build](plugins/build/README.md)                               | Build, test, and precommit automation                | Available   | Available |
| [builtin-tasks](plugins/builtin-tasks/README.md)               | Claude Code built-in task orchestration              | Available   | —         |
| [code](plugins/code/README.md)                                 | Code-quality and test-writing guidance               | Available   | Available |
| [ghostty-titles](plugins/ghostty-titles/README.md)             | Ghostty activity titles                              | Available   | Available |
| [git](plugins/git/README.md)                                   | Commit, rebase, conflict, branch, and worktree flows | Available   | Available |
| [github](plugins/github/README.md)                             | GitHub Actions diagnosis and pull-request workflows  | Available   | Available |
| [java](plugins/java/README.md)                                 | Maven and OpenRewrite workflows                      | Available   | Available |
| [justfile](plugins/justfile/README.md)                         | Justfile authoring utilities                         | Available   | Available |
| [orchestration](plugins/orchestration/README.md)               | Shared execution and finish conventions              | Available   | Available |
| [worktree-setup](plugins/worktree-setup/README.md)             | Claude worktree initialization hooks                 | Available   | —         |
| [claude-code-plans](plugins/claude-code-plans/)                | Session events for the claude-code-plans dashboard   | Available   | Available |
| [git-guards](plugins/git-guards/)                              | Guards against destructive Git commands              | Available   | Available |
| [plugin-and-skill-dev](plugins/plugin-and-skill-dev/README.md) | Plugin instruction-writing guidance                  | Available   | Available |
| [temporal-data](plugins/temporal-data/)                        | System-time temporal database patterns               | Available   | Available |
| [stop-phrase-guard](plugins/stop-phrase-guard/README.md)       | Guard against premature session termination          | Available   | Available |
| [bash-guards](plugins/bash-guards/README.md)                   | Guards against destructive shell commands            | Available   | Available |
| [investigation-report](plugins/investigation-report/)          | Self-contained HTML investigation reports            | Available   | Available |
| [tmux-reboot](plugins/tmux-reboot/)                            | Agent session snapshots around tmux restarts         | Available   | Available |
| [recap](plugins/recap/README.md)                               | End-of-turn request and link recaps                  | Available   | Available |

`builtin-tasks` depends on Claude Code's task, agent, and team tools.
`worktree-setup` depends on Claude Code's `WorktreeCreate` hook. Those capabilities have no Codex
equivalent in this repository, so the corresponding Codex entries are intentionally unavailable.

## Install for Claude Code

Register the GitHub marketplace once:

```bash
claude plugin marketplace add motlin/claude-code-plugins
```

Install a plugin by its catalog name:

```bash
claude plugin install markdown-tasks@motlin-claude-code-plugins
```

From a local clone, install all Claude Code plugins with:

```bash
./install-local.sh claude
```

Running `./install-local.sh` without an argument selects the same Claude Code mode.

## Install for Codex

Register the Codex marketplace, then add an available plugin:

```bash
codex plugin marketplace add motlin/claude-code-plugins
codex plugin add markdown-tasks@motlin-claude-code-plugins
```

Install every compatible plugin from a local checkout with:

```bash
./install-local.sh codex
```

Use `./install-local.sh all` to install both product variants. During plugin development, refresh
one installed Codex plugin from the checkout and start a new conversation:

```bash
just codex-reinstall markdown-tasks
```

## Install Individual Skills

The open [`skills`](https://github.com/vercel-labs/skills) CLI can discover skills directly from
the repository:

```bash
npx skills add motlin/claude-code-plugins --list
npx skills add . --list
```

Install a named skill for one agent:

```bash
npx skills add motlin/claude-code-plugins --skill markdown-tasks --agent codex
npx skills add motlin/claude-code-plugins --skill markdown-tasks --agent claude-code
```

This route installs skill instructions and their bundled resources. Use the product marketplace
when a workflow also requires hooks, slash commands, or custom agents.
