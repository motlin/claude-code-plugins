---
name: worktree
description: Create a git worktree in a peer directory using the plugin worktree script. Use when the user asks for a new worktree or a branch checked out beside the repo.
---

# Worktree

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/worktree/SKILL.md` file.

## Create the Worktree

Use the user's text as the branch name if it is already kebab-case (e.g., `auth-feature`); otherwise derive a short kebab-case name from it. From the repository root, run:

```bash
<plugin-root>/scripts/worktree.sh <branch-name>
```

On failure, stop and summarize the error. On success, report the worktree path.

## Opening a Terminal Tab

Open a terminal tab in the worktree only if the user explicitly asks.

In iTerm:

```bash
osascript -e 'tell application "iTerm"
    tell current window
        create tab with default profile
        tell current tab
            tell current session
                write text "cd <worktree-absolute-path>"
            end tell
        end tell
    end tell
end tell'
```

In xfce4-terminal:

```bash
xfce4-terminal --tab --working-directory="<worktree-absolute-path>" -x bash -c "cd <worktree-absolute-path>; exec bash"
```
