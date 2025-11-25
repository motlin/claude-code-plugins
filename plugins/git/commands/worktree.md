---
argument-hint: branch-name
description: Create a git worktree in a peer directory
---

🌳 Create Git Worktree

Create a git worktree in a peer directory.

## Arguments

The argument should be a kebab-case task name (e.g., "auth-feature", "database-migration").

The user passed in: `$ARGUMENTS`

If that text is already kebab case, use it directly as the branch name. Otherwise come up with a good kebab-case name based on what the user passed in.

## Steps

- Run `bash plugins/git/scripts/worktree.sh <branch-name>` from the repository root
- If the command exits with a non-success exit code, stop here and give a good summary to the user

## Conclusion

Run a command to create a new terminal tab in the newly created worktree.

If we are running in iTerm:

```console
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

If we are running in xfce4-terminal:

```console
xfce4-terminal --tab --working-directory="<worktree-absolute-path>" -x bash -c "cd <worktree-absolute-path>; exec bash"
```
