# ratchet

Keeps existing lint and test debt from growing and promotes zero-count rules into full enforcement.

## Command

### `/ratchet`

Check every configured strictness ratchet, or check one tool when given its stable identifier.

## Skill

The `ratchet` skill guides guarded baseline checks, explicit acceptance of improvements, coverage acknowledgement, and promotion into a tool's real enforcement configuration.

## Repository integration

Configure checked-in adapter commands in `.ratchet/config.json` and keep one canonical baseline at `.ratchet/<tool>.json`. The plugin includes machine-readable adapters for ShellCheck, markdownlint-cli2, yamllint, oxlint/Vite+, and Vitest/Vite+. Oxlint promotion requires a durable `.oxlintrc.json` rules object.

The Vitest adapter ratchets `SKIPPED_TESTS` (including todo, pending, and disabled tests) and `ZERO_TEST_FILES` (source files with executable statement counters that all remain zero) independently. It invokes the suite with Vitest's JSON reporter and coverage enabled, then rejects missing test files, missing source coverage, failed tests, malformed reports, and unknown assertion states before emitting counts. Coverage instrumentation makes zero-test-file detection slower than skipped-test counting, but the count remains local and cannot be offset by unrelated well-covered files. Promoted rules are recorded in the enforcement file and remain implicit-zero rules in the shared core, so the repository's required precommit path must run `just ratchet`. Per-file percentage floors and mutation scores are intentionally deferred.

Configure `.ratchet/vitest-adapter.json` with a repository-local command, explicit source and test file globs, and a repository-relative enforcement file:

```json
{
	"schemaVersion": 1,
	"command": ["node_modules/.bin/vp", "test", "run"],
	"sourceFileGlobs": ["packages/*/src/*.ts", "packages/*/src/**/*.ts"],
	"testFileGlobs": ["packages/*/test/*.test.ts", "packages/*/test/**/*.test.ts"],
	"enforcementFile": ".ratchet/vitest-enforcement.json"
}
```

Workflowy is the intended first consumer because it already uses Vitest through Vite+ and has an explicit source/test layout. This plugin repository remains a contract-test host because its own hook tests are not coverage-instrumented. `/grill-me` was unavailable during the decision, so the axis choice was pressure-tested directly against those repository constraints.

The public recipes are:

- `just ratchet [TOOL]` checks without writing.
- `just ratchet-accept TOOL` accepts only guarded positive decreases.
- `just ratchet-accept-coverage TOOL` acknowledges a fresh file-count change without changing rule counts.
- `just ratchet-promote TOOL RULE` verifies a zero count, enables durable error enforcement, scans again, and then removes the baseline entry.

Adapter failures, malformed reports, timeouts, and incomplete coverage never update a baseline.
