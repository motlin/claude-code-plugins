---
name: git-workflow
description: Commit message format and git workflow rules. ALWAYS use this skill for every git commit — no exceptions — and whenever rewording an existing commit message.
---

# Git Workflow

Commit with the `git:commit` skill. In Claude Code it may delegate to the `git:commit-handler` agent; in Codex, follow it directly unless the user asks for a subagent.

## Commit Message Format

Every commit message is a single line: no body, no bullet list, no extra paragraphs. It:

- Starts with a present-tense verb (Add, Fix, Replace, Remove, Update, …)
- Is 60-120 characters
- Ends with a period
- Avoids praise adjectives (comprehensive, robust, essential, best practices)

A task description or prompt is intent, not the message. Distill a long or multi-line prompt to one line; never copy it verbatim. This applies to new commits and to rewording existing ones with `git history reword`.

## Conflicts and Rebasing

Resolve conflicts with the `git:conflicts` skill. In Codex, spawn a subagent only when the user asks for subagents or parallel agent work.

Rebase the current branch on upstream with the `git:git-rebase` skill.

## Prefer Modern Git Commands

- `git switch` instead of `git checkout` for switching branches
- `git switch -c` instead of `git checkout -b` for creating branches
- `git restore` instead of `git checkout --` for restoring files
- `git restore --staged` instead of `git reset HEAD` for unstaging files
- `git replay --onto` instead of `git rebase --onto` for non-interactive onto rebases
- `git history reword` instead of interactive rebase or amending for editing commit messages
- `git history split` instead of interactive rebase for splitting commits
