# orchestration

Startup guidelines and the finish pipeline (commit, precommit, rebase, simplify, fixup, precommit) that runs before returning control.

- `orchestration:orchestration`: startup skill that routes to other skills
- `orchestration:finish`: the finish pipeline, via the `orchestration:finish` agent
- `orchestration:conversation-style`: response style
- `orchestration:llm-context`: working with `.llm/`

The pipeline uses agents from the `build`, `git`, and `code-simplifier` plugins; install them too.

## Setup

Add to `~/.claude/CLAUDE.md`:

```markdown
Always use the @orchestration:orchestration skill for core guidelines and workflow automation.
```
