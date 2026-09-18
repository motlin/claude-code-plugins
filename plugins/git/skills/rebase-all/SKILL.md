---
name: rebase-all
description: Rebase all local branches onto the configured upstream branch. Use when the user asks to rebase every branch or bring all branches up to date.
---

# Rebase All

Keep all branches in a repository up-to-date by rebasing them onto a configurable upstream branch.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/rebase-all/SKILL.md` file.

Run:

```bash
<plugin-root>/scripts/git-all
```

If it fails with merge conflicts, resolve all conflicts in the affected branch, then run the script again. Either use the `git:conflicts` skill inline or delegate to the `git:conflict-resolver` agent.

Repeat this cycle until the command completes without errors or conflicts.

When communicating:

- Clearly indicate which branch you're working on.
- Summarize the conflicts found.
- Report progress after each iteration.
- Notify when the entire rebase process is complete.
