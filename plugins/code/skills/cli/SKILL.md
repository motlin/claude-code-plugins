---
name: cli
description: CLI guidelines. Use whenever using the Bash tool, which is almost always. Also use when you see "command not found: __zoxide_z" errors.
---

# CLI Guidelines

## Directory Navigation

- I replaced `cd` with `zoxide`. Use `command cd` to change directories
  - This is the only command that needs to be prefixed with `command`
  - Don't prefix `git` with `command git`
- Try not to use `cd` or `zoxide` at all. It's usually not necessary with CLI commands
  - Don't run `cd <dir> && git <subcommand>`
  - Prefer `git -C <dir> <subcommand>`

## Flag Names

Prefer long flag names when available:

- Don't run `git commit -m`
- Run `git commit --message` instead
