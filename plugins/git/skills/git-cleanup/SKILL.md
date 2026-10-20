---
name: git-cleanup
description: Survey a repository's local git state and tidy it with the user's choices — uncommitted changes, untracked files, the upstream remote setting, and stale or duplicate branches — then rebase every branch. Use when the user asks to clean up, tidy, or sort out a git repository. Use git:wip instead for multi-worktree cleanup that also retests and pushes.
---

# Git Cleanup

Use the `code:cli` and `git:git-workflow` skills.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/git-cleanup/SKILL.md` file.

## Survey

Gather everything in one pass before changing anything:

```bash
git status --short --branch
git branch -vv
git worktree list
git stash list
git remote -v
git clean -nd
git clean -ndX
git count-objects -vH
```

For every local branch other than main, report commits ahead of and behind main, unmerged patches (`git cherry main <branch> | grep -c '^+'`), and last commit age. Read the diff of any uncommitted change so you can describe it.

## Report and Ask

Summarize the findings in a few short lines, then ask with `AskUserQuestion`, one question per area that has something to decide:

- **Uncommitted changes**: commit on the current branch, commit on a new branch, or discard.
- **Untracked files**: add to `.gitignore`, add to `.git/info/exclude` for files that are local to this machine (IDE folders, `.llm/`), commit them, or leave them.
- **Worktrees**: for each worktree other than the main one, remove it, keep it, or decide each one. Show each worktree's branch and `git -C <worktree> status --short`. A branch checked out in a worktree is skipped by the rebase.
- **Branches**: rebase all, review each branch, or delete the backups and duplicates. Point out the likely candidates: names with `backup`, near-identical names such as `fix-login` and `login-fix`, and branches whose patches all appear in another branch.

## Configure the Upstream Remote

The rebase and delete-merged scripts read `UPSTREAM_REMOTE`, which defaults to `upstream`. When `git remote` has no `upstream` and the project's `.envrc` does not set `UPSTREAM_REMOTE`, append the setting and re-allow it:

```bash
echo "export UPSTREAM_REMOTE=origin" >> .envrc
direnv allow .
```

The running shell does not reload `.envrc`, so also pass `UPSTREAM_REMOTE=origin` to the scripts in this session.

The scripts rebase onto the remote branch, not local main. If local main has commits the remote lacks, say so before rebasing, since the rebased branches will not include them.

## Apply the Choices

Commit with the `git:commit` skill. Edit `.gitignore` or `.git/info/exclude` as chosen.

Remove the chosen worktrees with the `git:clean-worktrees` skill before rebasing, so their branches get rebased too, then run `git worktree prune --verbose`. Removal is `git worktree remove`, never `--force`. When Git refuses because a worktree has changes, report it and ask whether to commit, stash, or keep that worktree.

Rebase with the `git:rebase-all` skill. It replays every branch it can, then rebases the rest.

When a rebase stops on conflicts, resolve them with the `git:conflicts` skill. When `git rerere` reports `Staged '<file>' using previous resolution`, still confirm the file has no conflict markers before continuing.

Never switch branches while a rebase is stopped. The checkout carries the stopped rebase onto the new branch, and the next `git rebase --continue` commits there. If it happens, run `git rebase --abort`, confirm with `git rev-parse` that every branch is back where it was, and redo that rebase.

## Verify

Show each branch's ahead and behind counts against the upstream branch, confirm `git status` is clean, and confirm no branch contains conflict markers:

```bash
git grep -lE '^(<<<<<<<|>>>>>>>) ' $(git for-each-ref --format='%(refname:short)' refs/heads)
```

Run the project's quickest relevant check on any committed change, such as `just --list` after editing a justfile.

## Offer the Outward-Facing Steps

The rebase rewrote every branch locally. Say that branches already on the remote need a `--force-with-lease` push, and do not push unless the user asks.

Offer to compare and delete the backup branches named in the report.

## Clean Up Duplicates and Merged Branches

Do these without asking; the user always wants them. This overrides the `git:rebase-all` skill's instruction to ask before running `delete-merged`.

The rebase skips a branch that points at the same commit as another branch, which leaves both on the old base. Delete the local-only twin of each such pair, keeping the branch that has a remote counterpart. Record each deleted branch's SHA first so it can be restored.

Run `<plugin-root>/scripts/delete-merged`. It deletes local branches merged into upstream main and runs `git push --delete origin` for merged remote branches.
