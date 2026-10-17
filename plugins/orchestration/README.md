# orchestration

Startup guidelines and the finish pipeline (commit, precommit, rebase, simplify, fixup, precommit) that runs before returning control.

- `orchestration:orchestration`: startup skill that routes to other skills
- `orchestration:finish`: the finish pipeline
- `orchestration:conversation-style`: response style
- `orchestration:llm-context`: working with `.llm/`
- `orchestration:memory`: fix the owning skill or CLAUDE.md instead of saving a memory

The pipeline uses skills from the `build` and `git` plugins; install them too.

## Setup

Add to `~/.claude/CLAUDE.md`:

```markdown
Always use the @orchestration:orchestration skill for core guidelines and workflow automation.
```
