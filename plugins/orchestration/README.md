# Orchestration Plugin

Core orchestration and context guidelines for Claude Code. This plugin consolidates all global instructions previously stored in `~/.claude/instructions/` into a single skill.

## Features

- **Conversation Style**: Guidelines for interacting with users (no compliments, direct communication)
- **Code Style**: Philosophy for writing code (strict types, no abbreviations, minimal comments)
- **Testing Philosophy**: Best practices for tests (strict assertions, avoid mocks)
- **Tool Conventions**: CLI usage patterns (zoxide, git, long flag names)
- **LLM Context**: Understanding `.llm/` directory structure
- **Workflow Orchestration**: When to invoke precommit, commit, and rebase agents

## Skills

- `orchestration` - Always-active skill providing core guidelines and workflow automation

## Usage

After installing this plugin, update your `~/.claude/CLAUDE.md` to:

```markdown
# 🤖 Instructions for LLMs

Always use the @orchestration:orchestration skill for core guidelines and workflow automation.
```

This replaces the previous `@instructions/*` references.
