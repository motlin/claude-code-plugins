---
name: memory
applies: has-memories
shard: whole-repo
invokes: "orchestration:memory over the repository's auto-memory files, scoped to {paths}"
evidence: "Each change cites the memory file and the reason: the file, commit or command output that contradicts it, the instruction file that already says it, or the docs section the branch moved it into."
---

Prune and promote the repository's auto-memory files, following the `orchestration:memory` skill on where a lesson belongs. The folder is `~/.claude/projects/<slug>/memory/`, where `<slug>` is the absolute path of the repository itself, never of your worktree, with every character other than a letter or digit replaced by `-`. Read every memory file and its `MEMORY.md` index.

Before changing anything there, copy the whole folder to `~/.claude/projects/<slug>/memory-backup-<date>/`, beside it, using the run date from your branch name. The folder is outside git, so that copy is the only way back.

Sort each memory into one of these, and act on it:

- **Wrong:** the code, git history or config contradicts it. Delete it, or correct it in place when the corrected fact still earns a memory. Cite what contradicts it.
- **Dead:** accurate, but obvious from the code, already said by a `CLAUDE.md`, skill or other instruction file, about work that has finished, or a patch for a gap that has since been fixed. Delete it, or shrink it to the part that is not dead.
- **Portable:** accurate and worth keeping for anyone who works on the repository, not only this user on this machine. Move it into the file that owns the topic: the project's `CLAUDE.md` or `AGENTS.md`, the skill or doc it is about, or a doc under the shard. Commit that edit on your branch, and do not delete the memory yourself: return its deletion, with its `MEMORY.md` line, as an `afterKept` step, so it is deleted only once the branch survives review.
- **Personal:** accurate, still useful, and about this user's preferences or setup. Leave it.

Delete and shrink wrong and dead memories in the memory folder directly, and update `MEMORY.md` to match: no line for a deleted file, and no file without a line. Name each one with its reason in your summary and evidence, so the report says what changed outside git. When a memory is ambiguous, leave it and return a finding instead.

Commit only the docs edits for portable memories. A run that only deleted or shrank memories commits nothing and returns committed: false with its changes in the summary.
