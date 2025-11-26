# build

Test and build automation tools that loop until all commits pass.

## Commands

### `/test-branch`

Test all commits in the current branch, automatically fixing failures in a loop until all commits pass.

### `/test-all`

Run tests on all commits and fix failures in a loop using the `build-fixer-autosquash` agent.

### `/fix`

Run `just precommit` and fix any failures that occur without committing.

## Requirements

This plugin requires:

- `git-test` - for testing commits (`pip install git-test` or `uv tool install git-test`)
- `uv` - for running pre-commit hooks (`pip install uv`)
- A project justfile with a `precommit` recipe (for `/fix` command only)

## Environment Variables

Configure the upstream branch for rebasing:

- `UPSTREAM_REMOTE` - Remote to rebase onto (default: `upstream`)
- `UPSTREAM_BRANCH` - Branch to rebase onto (default: `main`)
- `GIT_TESTS` - Test configuration name for git-test (default: `default`)
- `FAIL_FAST` - Stop on first failure in test-all (default: `false`)
