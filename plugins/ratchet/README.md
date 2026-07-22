# ratchet

Keeps existing lint and test debt from growing and promotes zero-count rules into full enforcement.

## Command

### `/ratchet`

Check every configured strictness ratchet, or check one tool when given its stable identifier.

## Skill

The `ratchet` skill guides guarded baseline checks, explicit acceptance of improvements, coverage acknowledgement, and promotion into a tool's real enforcement configuration.

## Repository integration

Configure checked-in adapter commands in `.ratchet/config.json` and keep one canonical baseline at `.ratchet/<tool>.json`. The plugin includes machine-readable adapters for ShellCheck, markdownlint-cli2, yamllint, and oxlint/Vite+. Oxlint promotion requires a durable `.oxlintrc.json` rules object.

The public recipes are:

- `just ratchet [TOOL]` checks without writing.
- `just ratchet-accept TOOL` accepts only guarded positive decreases.
- `just ratchet-accept-coverage TOOL` acknowledges a fresh file-count change without changing rule counts.
- `just ratchet-promote TOOL RULE` verifies a zero count, enables durable error enforcement, scans again, and then removes the baseline entry.

Adapter failures, malformed reports, timeouts, and incomplete coverage never update a baseline.
