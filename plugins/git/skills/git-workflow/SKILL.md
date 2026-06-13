---
name: git-workflow
description: Commit message format and git workflow rules. ALWAYS use this skill for every git commit — no exceptions — and whenever rewording an existing commit message.
---

# Git Workflow Best Practices

This skill provides guidelines for git operations including commits, conflict resolution, and branch management.

## Commit Guidelines

Use the `git-commit` skill for commit operations. In Claude Code this may delegate to the `git:commit-handler` agent; in Codex, follow the `git-commit` skill directly unless the user explicitly asks for a subagent workflow.

### Commit Message Format

Every commit message is a **single line** — no body, no bullet list, no blank-line-separated paragraphs. It must:

- Start with a present-tense verb (Add, Fix, Replace, Remove, Update, …)
- Be 60-120 characters
- End with a period
- Avoid praise adjectives (comprehensive, robust, essential, best practices)

A task description or prompt is **intent, not the message**. When the prompt is long or multi-line, distill it to one line — never copy it verbatim into the commit message. This rule applies to writing new commits and to rewording existing ones with `git history reword`.

## Conflict Resolution

Use the `git-conflicts` skill to resolve git merge or rebase conflicts. In Codex, spawn a subagent only when the user explicitly asks for subagents or parallel agent work.

## Rebasing

Use the `git-rebase` skill to rebase the current branch on upstream.

## Prefer Modern Git Commands

Use newer git commands instead of their legacy equivalents whenever possible:

- `git switch` instead of `git checkout` for switching branches
- `git switch -c` instead of `git checkout -b` for creating branches
- `git restore` instead of `git checkout --` for restoring files
- `git restore --staged` instead of `git reset HEAD` for unstaging files
- `git replay --onto` instead of `git rebase --onto` for non-interactive onto rebases
- `git history reword` instead of interactive rebase or amending for editing commit messages
- `git history split` instead of interactive rebase for splitting commits
