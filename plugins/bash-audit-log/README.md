# bash-audit-log

Logs every bash command executed by Claude Code with an ISO timestamp to `~/.claude/bash-commands.log`.

## Log Format

```
[2026-04-29T12:34:56Z] git status
[2026-04-29T12:34:57Z] npm test
```

## How It Works

A PostToolUse hook on Bash extracts the command from the tool input JSON and appends a timestamped line to the log file.
