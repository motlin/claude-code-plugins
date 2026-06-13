---
name: git-rebase
description: Rebase local commits on the configured upstream using the plugin rebase script.
---

# Git Rebase

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/git-rebase/SKILL.md` file.

## Verify Clean Tree

Run `git status`. If there are uncommitted changes, stop and report them.

## Run Rebase Script

Run exactly:

```bash
<plugin-root>/scripts/rebase
```

Do not add arguments or environment overrides. Do not use raw `git rebase`, `git replay`, `git pull --rebase`, or `git rebase @{upstream}`.

## Handle Outcomes

- Success: report success.
- Merge conflicts: use the `git-conflicts` skill.
- Other errors: report the specific error and stop.
