# build

Git-test driven precommit, branch testing, and dev server tools.

- `/build:precommit`: run `git test run HEAD` after code changes, skipped on battery
- `/build:fix`: run precommit and fix failures without committing
- `/build:test-branch`: test every commit on the branch and fix failures in a loop
- `/build:test-all`: the same loop across every local branch
- `/build:test-setup`: configure `git test` for the repository
- `/build:dev-server`: start a dev server on a fixed port and restart it when it dies
- `precommit-runner` and `build-fixer-autosquash` agents
- `Stop` hook: warns when HEAD has no `git test` result

Requires `git-test` (`uv tool install git-test`) and a `just precommit` recipe. Environment: `UPSTREAM_REMOTE` (default `upstream`), `UPSTREAM_BRANCH` (default `main`), `GIT_TESTS` (default `default`), `FAIL_FAST` (default `false`).
