---
name: commit-chunks
description: Split local changes into multiple logical commits. Use when the user asks to commit changes in chunks or as several commits.
---

# Commit Chunks

Use the `code:cli` and `git:git-workflow` skills.

Inspect the local changes as in the `git:commit` skill and group them into logical commits. Show every proposed commit at once, each with its message and file list, and wait for the user's confirmation.

Then make each commit following the `git:commit` skill: stage files individually, write a single-line message, echo the `Running:` line, and handle pre-commit hooks without `--no-verify`.
