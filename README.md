# Claude Code and Codex Plugins

Collection of plugins for Claude Code and Codex that enhance terminal integration, task management,
and development workflows.

## Plugin Compatibility

Claude Code installs plugins from `.claude-plugin/marketplace.json`. Codex installs the translated
plugins marked `AVAILABLE` in `.agents/plugins/marketplace.json`.

| Plugin                                                   | Claude Code | Codex         |
| -------------------------------------------------------- | ----------- | ------------- |
| [orchestration](plugins/orchestration/README.md)         | Available   | Available     |
| [markdown-tasks](plugins/markdown-tasks/README.md)       | Available   | Available     |
| [tmux-titles](plugins/tmux-titles/README.md)             | Available   | Available     |
| [iterm2-titles](plugins/iterm2-titles/README.md)         | Available   | Available     |
| `ghostty-titles`                                         | Available   | Available     |
| [build](plugins/build/README.md)                         | Available   | Available     |
| [code](plugins/code/README.md)                           | Available   | Available     |
| [git](plugins/git/README.md)                             | Available   | Available     |
| [github](plugins/github/README.md)                       | Available   | Available     |
| [java](plugins/java/README.md)                           | Available   | Available     |
| [justfile](plugins/justfile/README.md)                   | Available   | Available     |
| `git-guards`                                             | Available   | Available     |
| `plugin-and-skill-dev`                                   | Available   | Available     |
| `temporal-data`                                          | Available   | Available     |
| [stop-phrase-guard](plugins/stop-phrase-guard/README.md) | Available   | Available     |
| `bash-guards`                                            | Available   | Available     |
| `investigation-report`                                   | Available   | Available     |
| `builtin-tasks`                                          | Available   | Not available |
| [worktree-setup](plugins/worktree-setup/README.md)       | Available   | Not available |
| `claude-code-plans`                                      | Available   | Available     |

The intentionally unavailable Codex entries remain visible in the Codex marketplace metadata so
the two marketplaces stay in one-to-one parity:

- `builtin-tasks` still exposes Claude-specific commands and agents rather than Codex skill
  entrypoints.
- `worktree-setup` depends on Claude Code's `WorktreeCreate` hook, which Codex does not support.

`claude-code-plans` sends `SessionStart`, `PostToolUse`, and `Stop` from Codex. Claude Code also
sends `SessionEnd`, `TaskCompleted`, and `WorktreeCreate`.

## Open Agent Skills

The skills in this repository follow the [Agent Skills specification](https://agentskills.io/) and
can be discovered or installed with Vercel's open [`skills`](https://github.com/vercel-labs/skills)
CLI independently of the Claude Code and Codex plugin marketplaces.

List every skill published from the default branch:

```bash
npx skills add motlin/claude-code-plugins --list
```

List skills from a local checkout, including unmerged branch work:

```bash
npx skills add . --list
```

Install one skill for Codex or Claude Code:

```bash
npx skills add motlin/claude-code-plugins --skill markdown-tasks --agent codex
npx skills add motlin/claude-code-plugins --skill markdown-tasks --agent claude-code
```

The `skills` CLI installs skill instructions and bundled resources. Use the product-specific plugin
marketplaces below when hooks, commands, agents, or other plugin capabilities are also required.

## Claude Code Installation

Add the marketplace from GitHub:

```bash
claude plugin marketplace add motlin/claude-code-plugins
```

For local development or use behind a firewall, clone the repository and run:

```bash
./install-local.sh
```

The no-argument invocation remains equivalent to `./install-local.sh claude`. Install an individual
plugin from the registered marketplace with:

```bash
claude plugin install markdown-tasks@motlin-claude-code-plugins
```

## Codex Installation

Add the marketplace from GitHub:

```bash
codex plugin marketplace add motlin/claude-code-plugins
```

Then install any available plugin:

```bash
codex plugin add markdown-tasks@motlin-claude-code-plugins
```

For local development, clone the repository and install every Codex-compatible plugin from the
local marketplace:

```bash
./install-local.sh codex
```

Use `./install-local.sh all` to install both product variants. Codex mode re-registers a marketplace
of the same name when it points elsewhere and reinstalls already-installed local plugins so the
Codex cache reflects the checked-out source.

After changing one local Codex plugin, use the focused cache-aware refresh instead of reinstalling
the full marketplace:

```bash
just codex-reinstall markdown-tasks
```

Start a new Codex conversation after reinstalling so skill discovery uses the refreshed plugin.

## Terminal Title Hooks

The `tmux-titles`, `iterm2-titles`, and `ghostty-titles` plugins preserve the richer Claude event
set in `hooks/claude-hooks.json`; their Claude manifests load that file explicitly. Codex discovers
`hooks/hooks.json` by convention, and those default manifests contain only events supported by both
products. The hook scripts accept each product's tool-name and working-directory payload fields.
