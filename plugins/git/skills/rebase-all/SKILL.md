---
name: rebase-all
description: Rebase all local branches onto the configured upstream branch. Use when the user asks to rebase every branch or bring all branches up to date.
---

# Rebase All

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/rebase-all/SKILL.md` file.

Run:

```bash
<plugin-root>/scripts/git-all
```

If it stops on merge conflicts, resolve them in the affected branch with the `git:conflicts` skill or the `git:conflict-resolver` agent, then run the script again. Repeat until it completes without errors or conflicts, naming the branch you're on and summarizing the conflicts after each pass.
