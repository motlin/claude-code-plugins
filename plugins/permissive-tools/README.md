# permissive-tools

Blanket-allows core Claude Code tools and common unix utilities without permission prompts.

## Permissions granted

| Tool      | Scope                  |
| --------- | ---------------------- |
| Bash      | All commands (blanket) |
| Edit      | All files              |
| Read      | All files              |
| Search    | All patterns           |
| WebSearch | All queries            |
| Write     | All files              |

## Unix utilities allowed

`cat`, `chmod`, `cp`, `curl`, `echo`, `find`, `grep`, `head`, `jq`, `ln`, `ls`, `mkdir`, `rm`, `sqlite3`

## Note

This plugin grants broad permissions. Pair it with guard plugins like `credential-guards`, `dangerous-command-guards`, `bash-guards`, and `git-guards` to maintain safety while reducing permission prompts.
