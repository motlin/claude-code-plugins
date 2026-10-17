---
name: memory
description: Decide where a lesson belongs before saving a memory. Use before every memory write, and whenever a correction or preference seems worth remembering.
---

# Memory

Skills, commands, agents, and CLAUDE.md files are markdown too. When a lesson is about how one of them behaves, edit that file. Don't write a memory for it.

## Find the owner

Before writing a memory, ask which instructions governed the behavior that went wrong:

- A skill, command, or agent from a plugin: edit its source in the plugin's git repository.
- A project's `CLAUDE.md` or `AGENTS.md`: edit that file.
- The user's global `~/.claude/CLAUDE.md`: edit it, or propose the edit when it is outside the current task.

## Keep the fix lean

Add only the rule the correction showed. Leave out lists of examples, destinations, or past decisions that a later session can infer from the files on disk.

- Skip decisions that happened once, and decisions the session got right on its first guess. A later session will guess right too.
- Record a convention only when it breaks the obvious default, such as a naming scheme that differs from the rest of the folder.
- Don't add rationale or "how to apply" sections, and don't expand existing ones to cover new rules.

## What still belongs in memory

Write a memory only for a fact that no instruction file owns.

A memory that patches a gap in a skill should be deleted once the skill is fixed.
