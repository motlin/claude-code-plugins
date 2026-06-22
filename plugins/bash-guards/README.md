# bash-guards

Blocks dangerous bash commands before they execute.

## Guards

| Command                             | Action | Suggestion          |
| ----------------------------------- | ------ | ------------------- |
| `rm -r`, `rm -rf`, `rm --recursive` | Deny   | Use `trash` instead |

Recursive `rm` is detected wherever the flag appears — after the operand (`rm dir -rf`), when invoked by path (`/bin/rm -rf`), or after another command (`… | xargs rm -rf`). Words that merely end in `rm` (`charm -rf`) and recursive flags on a later command (`rm foo && ls -R`) are left alone.
