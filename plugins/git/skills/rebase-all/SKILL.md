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
<plugin-root>/scripts/rebase-all
```

The script first runs `replay-all`, which moves every branch that replays cleanly without checking it out, then rebases only the branches replay left behind.

It reads `UPSTREAM_REMOTE`, which defaults to `upstream`. When the repository has no `upstream` remote, pass `UPSTREAM_REMOTE=origin`, and suggest adding `export UPSTREAM_REMOTE=origin` to the project's `.envrc`.

If it stops on merge conflicts, resolve them in the affected branch with the `git:conflicts` skill, then run the script again. Repeat until it completes without errors or conflicts, naming the branch you're on and summarizing the conflicts after each pass.

Once every branch is rebased, offer to clean up merged branches with `<plugin-root>/scripts/delete-merged`. It deletes local branches merged into upstream main and also runs `git push --delete origin` for merged remote branches, so it is outward-facing. Ask the user before running it, and skip it if they decline.
