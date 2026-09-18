---
name: worktree
description: Create a git worktree in a peer directory using the plugin worktree script. Use when the user asks for a new worktree or a branch checked out beside the repo.
---

# Worktree

Create a git worktree in a peer directory.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/worktree/SKILL.md` file.

## Branch Name

The user supplies a kebab-case task name (e.g., "auth-feature", "database-migration"). If the text they passed is already kebab-case, use it directly as the branch name. Otherwise derive a short kebab-case name from what they passed in.

## Create the Worktree

From the repository root, run:

```bash
<plugin-root>/scripts/worktree.sh <branch-name>
```

If the command exits with a non-success exit code, stop here and give a good summary to the user.

If it succeeds, report the created worktree path.

## Opening a Terminal Tab

Open a new terminal tab in the worktree only if the user explicitly asks.

If running in iTerm:

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

If running in xfce4-terminal:

```bash
xfce4-terminal --tab --working-directory="<worktree-absolute-path>" -x bash -c "cd <worktree-absolute-path>; exec bash"
```
