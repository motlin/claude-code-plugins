# build

Test and build automation tools that loop until all commits pass.

Requires `just` command runner with specific global recipes configured.

## Commands

### `/test-branch`
Test all commits in the current branch, automatically fixing failures in a loop until all commits pass. Uses `just --global-justfile test-branch`.

### `/test-all`
Run tests on all commits and fix failures in a loop using the `build-fixer-autosquash` agent. Uses `just --global-justfile test-all`.

### `/fix`
Run `just precommit` and fix any failures that occur without committing.

## Requirements

This plugin assumes you have a global justfile with:
- `test-branch` recipe - tests each commit
- `test-all` recipe - tests all commits
- `test-fix` recipe - creates fixup commits and rebases
