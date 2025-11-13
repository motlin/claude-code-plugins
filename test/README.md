# Plugin Hook Test Suite

Automated testing framework for validating Claude Code plugin hooks.

## Overview

This test suite validates that plugin hooks are correctly configured and that hook scripts behave as expected. It addresses the challenge that Anthropic documentation only suggests manual testing with `claude --debug`.

## Running Tests

```bash
./test/run-tests.sh
```

Or from the project root:

```bash
just test
```

## Test Structure

### Test Framework (`test/lib/test-framework.sh`)

Lightweight bash testing framework with assertion functions:

- `test "description"` - Declares a test case
- `assert_equal expected actual [message]` - Assert equality
- `assert_contains haystack needle [message]` - Assert substring presence
- `assert_exit_code expected actual [message]` - Assert exit code
- `assert_json_field json field expected [message]` - Assert JSON field value

### Hook Helpers (`test/lib/hook-helpers.sh`)

Utilities for testing hooks:

- `create_test_json cwd tool_name [extra_fields]` - Generate test JSON input
- `run_hook_script script_path input_json [args...]` - Execute hook with JSON stdin
- `validate_hooks_json hooks_file` - Validate hooks.json structure
- `get_hook_commands hooks_file event_type` - Extract commands from hooks.json
- `get_hook_type hooks_file event_type [index]` - Get hook type field
- `check_hook_type_consistency hooks_file script_path` - Verify type matches stdin usage

## Test Files

### `test/hooks/test-hooks-json-validation.sh`

Validates hooks.json configuration:

- JSON syntax validity
- Expected event types are defined
- Hook type consistency (stdin vs command)
- Hook commands reference existing scripts

### `test/hooks/test-tmux-hooks.sh`

Tests tmux plugin hook scripts:

- Early exit when TMUX/TMUX_PANE not set
- JSON parsing and field extraction
- Tool icon selection logic
- Directory name extraction

### `test/hooks/test-iterm2-hooks.sh`

Tests iTerm2 plugin hook scripts:

- JSON parsing and field extraction
- Tool icon selection logic
- Directory name extraction
- Escape code format

## Test Design Philosophy

### No External Dependencies

The framework uses pure bash with only standard utilities (jq, grep, etc.). No need to install BATS, shunit2, or other testing frameworks.

### Fail Loud

Tests validate that scripts fail loudly when expected data is missing, with no silent fallbacks to environment variables or default values.

### Type Consistency

The bug that motivated this test suite was hooks.json files using inconsistent 'type' values. Scripts that read JSON from stdin must use `type: "command"` (which actually means stdin in Claude Code's hook system).

### Real Script Testing

Tests use temporary scripts that mirror the logic of actual hook scripts, validating the patterns used throughout the codebase.

## Adding New Tests

Create a new test file in `test/hooks/`:

```bash
#!/bin/bash

set -Eeuo pipefail

script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/test-framework.sh"
source "$script_dir/../lib/hook-helpers.sh"

PROJECT_ROOT="$(command cd "$script_dir/../.." && pwd)"

test "your test description"
test_json=$(create_test_json "/test/path" "ToolName")
output=$(echo "$test_json" | "$PROJECT_ROOT/path/to/script.sh" 2>&1)
assert_contains "$output" "expected"

exit $TESTS_FAILED
```

Add the test file to `test/run-tests.sh`:

```bash
test_files=(
  "$script_dir/hooks/test-hooks-json-validation.sh"
  "$script_dir/hooks/test-tmux-hooks.sh"
  "$script_dir/hooks/test-iterm2-hooks.sh"
  "$script_dir/hooks/test-your-new-test.sh"  # Add here
)
```

## Historical Context

This test suite was created after discovering that hooks.json files had inconsistent 'type' values. Some hooks used 'command' type but scripts expected JSON stdin, causing silent failures where hooks didn't receive expected data. Scripts had fallback logic to `$PWD` that masked the problem.

The suite ensures:
- Hooks have correct 'type' field (command for stdin)
- Scripts receive JSON with required fields
- Scripts parse JSON correctly without falling back to environment variables
- Scripts fail loudly when expected data is missing
