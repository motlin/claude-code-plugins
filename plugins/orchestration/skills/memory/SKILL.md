---
name: memory
description: Decide where a lesson belongs before saving a memory. Use before every memory write, and whenever a correction or preference seems worth remembering.
---

# Memory

Skills, commands, agents, and CLAUDE.md files are markdown too. When a lesson is about how one of them behaves, edit that file. Don't write a memory for it.

## Find the owner

Before writing a memory, ask which instructions governed the behavior that went wrong:

- A skill, command, or agent from a plugin: edit its source in the plugin's git repository, never the copy under `~/.claude/plugins/cache/`, which gets overwritten on the next update. Make the edit in a worktree.
- A project's `CLAUDE.md` or `AGENTS.md`: edit that file.
- The user's global `~/.claude/CLAUDE.md`: edit it, or propose the edit when it is outside the current task.

If one of these owns the behavior, the fix goes there, and no memory is written.

## Keep the fix lean

Add only the rule the correction showed. Leave out lists of examples, destinations, or past decisions that a later session can infer from the files on disk.

## What still belongs in memory

Write a memory only for a fact that no instruction file owns. Examples: who the user is, the state of an ongoing project, or a pointer to an external resource.

A memory that patches a gap in a skill is a bug report filed in the wrong place. Delete it once the skill is fixed.
