🌳 Create Git Worktree(s) for Next Available Todo(s)

You are to create $ARGUMENTS new git worktree(s) in peer directories for the first available todo items

## Todo context
The task list is in `.llm/todo.md`. The format is:

```markdown
- `[ ]` - Not started
- `[x]` - Completed
- `[>]` - In progress in a peer directory/worktree
```

## Steps

- Find the next incomplete task
  - Use the `@markdown-tasks` skill to extract the first incomplete task from `.llm/todo.md`
  - It returns the first `Not started` task

- Come up with a kebab-case task name based on the todo item (e.g., "auth-feature", "database-migration")

- Create the worktree:
  - Run `bash plugins/markdown-tasks/skills/markdown-tasks/scripts/worktree <task-name>` from the repository root
  - This command marks the task with `[>]` and creates the worktree
  - If the command exits with a non-success exit code, stop here and give a good summary to the user

- Edit the original todo file to add a comment indicating which worktree is working on the task:
```markdown
- [>] Implement user authentication with JWT <!-- worktree: auth-feature -->
```

## Conclusion

Run a command to create a new terminal tab in the newly created worktree, and run `claude /todo` in that tab.

If we are running in iTerm:

```console
osascript -e 'tell application "iTerm"
    tell current window
        create tab with default profile
        tell current tab
            tell current session
                write text "cd <worktree-absolute-path>"
                write text "claude /todo"
            end tell
        end tell
    end tell
end tell'
```

If we are running in xfce4-terminal:

```console
xfce4-terminal --tab --working-directory="<worktree-absolute-path>" -x bash -c "cd <worktree-absolute-path> && claude code /todo; exec bash"
```

## Loop

Say how many worktrees you have created.

Repeat the instructions to create another worktree until you have created $ARGUMENTS worktrees.

