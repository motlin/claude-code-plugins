# bash-guards

Blocks dangerous bash commands before they execute.

## Guards

| Command                             | Action | Suggestion          |
| ----------------------------------- | ------ | ------------------- |
| `rm -r`, `rm -rf`, `rm --recursive` | Deny   | Use `trash` instead |
