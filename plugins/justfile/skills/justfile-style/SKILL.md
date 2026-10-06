---
name: justfile-style
description: Style guidelines for justfile recipes, extracted scripts and configuration, documentation, and dependencies. Use when writing or editing justfiles.
---

# Justfile Style

## Extract scripts and configuration

Keep recipes focused on orchestration. Do not embed script bodies in heredocs or multiline quoted strings; even short SSH status or provisioning blocks belong in standalone script files. Keep structured configuration payloads such as JSON and JQ in separate configuration or template files.

Pass runtime values as arguments or environment variables instead of interpolating them into script source. For remote execution, stream the script to the appropriate interpreter, for example:

```justfile
    ssh "${SSH_TARGET}" bash -s -- "${CONTAINER}" \
        < "{{ justfile_directory() }}/.just/scripts/container-status.sh"
```

Preserve quoting, stdin usage, exit codes, and execution order when extracting. Keep secrets out of process arguments. Validate the extracted scripts locally without invoking deployment or provisioning as a test.

Within the requested scope, scan related recipes for remaining heredocs and multiline script or configuration strings rather than stopping after the first named example.

## Doc comments for short recipes

When a recipe body is a single line of roughly 120 characters or less, make its doc comment the command itself instead of a descriptive phrase. The command tells the reader exactly what runs.

Before:

```justfile
# Install dependencies
[group('setup')]
install:
    npm install
```

After:

```justfile
# npm install
[group('setup')]
install:
    npm install
```

Keep a descriptive doc comment for shebang recipes, multi-line recipes, and single-line commands longer than about 120 characters.

## Recipe dependencies

When a recipe needs other recipes to run first, prefer declaring them as dependencies over calling `just` from a recipe body or from a script the recipe runs. Dependencies run once per invocation even when several recipes share them, and avoid spawning a second `just` process.

Before:

```justfile
# Build, then run tests
test:
    just build
    ./scripts/run-tests.sh
```

After:

```justfile
# ./scripts/run-tests.sh
test: build
    ./scripts/run-tests.sh
```

Pass arguments with parentheses, as in `test: (build "release")`. Put recipes that must run after the body behind `&&`, as in `release: build && publish`.

When several recipes begin with the same commands, extract those commands into their own recipe and declare it as a dependency of each. In a large graph of recipes, a shared dependency runs once per invocation, so `just lint test` does the common work once instead of repeating it in every body.

Before:

```justfile
# Install, then lint
lint:
    npm ci
    npm run lint

# Install, then test
test:
    npm ci
    npm test
```

After:

```justfile
# npm ci
install:
    npm ci

# npm run lint
lint: install
    npm run lint

# npm test
test: install
    npm test
```
