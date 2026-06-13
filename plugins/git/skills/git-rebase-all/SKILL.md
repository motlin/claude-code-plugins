---
name: git-rebase-all
description: Rebase all local branches onto the configured upstream branch.
---

# Git Rebase All

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/git-rebase-all/SKILL.md` file.

Run:

```bash
<plugin-root>/scripts/git-all
```

If it fails with merge conflicts, use the `git-conflicts` skill to resolve conflicts in the affected branch, then run the script again.

Repeat until the command completes without errors or conflicts.

Report which branch is being processed, summarize conflicts, and report final completion.
