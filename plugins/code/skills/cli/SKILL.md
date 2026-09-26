---
name: cli
description: 'CLI guidelines. Use whenever using the Bash tool, which is almost always. Also use when you see "command not found: __zoxide_z" errors.'
---

# CLI Guidelines

- `cd` is replaced with `zoxide`. Use `command cd` to change directories. No other command needs the `command` prefix; don't write `command git`.
- Avoid changing directories at all. Instead of `cd <dir> && git <subcommand>`, run `git -C <dir> <subcommand>`.
- Prefer long flag names: `git commit --message`, not `git commit -m`.
