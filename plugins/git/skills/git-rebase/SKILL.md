---
name: git-rebase
description: Rebase local commits on the configured upstream using the plugin rebase script.
---

# Git Rebase

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/git-rebase/SKILL.md` file.

Run `git status`. If there are uncommitted changes, stop and report them.

Then run exactly this, with no added arguments or environment overrides:

```bash
<plugin-root>/scripts/rebase
```

The script reads the project's configured upstream remote and branch (usually `origin/main`). Other rebase commands pick the wrong base: `git rebase` and `git replay` don't know the upstream, and `git pull --rebase` and `git rebase @{upstream}` use the branch's tracking info, such as `origin/<current-branch>`.

## Outcomes

- Success: report success.
- Merge conflicts: use the `git:conflicts` skill.
- Other errors: report the specific error and stop.
