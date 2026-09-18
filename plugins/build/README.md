# build

Test and build automation tools that loop until all commits pass.

## Skills

### `/build:test-branch`

Test all commits in the current branch, automatically fixing failures in a loop until all commits pass.

### `/build:test-all`

Run tests on all commits of every local branch and fix failures in a loop using the `build:build-fixer-autosquash` agent.

### `/build:fix`

Run precommit checks and fix any failures that occur without committing.

### `/build:test-setup`

Configure `git test` for the current repository so that `build:test-branch` and `build:test-all` work.

### `/build:dev-server`

Start the project's dev server on a consistent port, wait until it is ready, and restart it when it stops responding.

### `/build:precommit`

Run precommit checks after code changes, skipping the build on battery power.

## Requirements

This plugin requires:

- `git-test` - for testing commits (`pip install git-test` or `uv tool install git-test`)
- `uv` - for running pre-commit hooks (`pip install uv`)
- A project justfile with a `precommit` recipe (for the test command that `/build:test-setup` configures)

## Environment Variables

Configure the upstream branch for rebasing:

- `UPSTREAM_REMOTE` - Remote to rebase onto (default: `upstream`)
- `UPSTREAM_BRANCH` - Branch to rebase onto (default: `main`)
- `GIT_TESTS` - Test configuration name for git-test (default: `default`)
- `FAIL_FAST` - Stop on first failure in test-all (default: `false`)
