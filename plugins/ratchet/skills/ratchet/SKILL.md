---
name: ratchet
description: Keep existing lint and test debt from growing by checking per-rule baselines, accepting only guarded decreases, and promoting zero-count rules into full enforcement. Use when a repository has .ratchet baselines or the user asks to check, accept, or promote a strictness ratchet.
---

# Strictness Ratchet

Use the repository's configured ratchet commands to compare current per-rule violations with committed baselines. A decrease in one rule never offsets an increase in another.

## Check without writing

- Run `just ratchet` for every configured adapter or `just ratchet TOOL` for one stable tool identifier.
- Treat checks as read-only. Do not rewrite a baseline because the current count changed.
- Distinguish regressions, unaccepted improvements, promotion opportunities, and infrastructure failures from the command's diagnostics and exit status.
- Never interpret a crash, timeout, malformed report, unknown report version, or incomplete file scan as zero findings.

## Accept guarded improvements

- Use `just ratchet-accept TOOL` only after a fresh successful scan proves that positive per-rule counts decreased.
- Never raise a baseline and never edit counts by hand to make a check pass.
- When discovered file coverage changes, use `just ratchet-accept-coverage TOOL` separately. Coverage acceptance must not alter rule counts.

## Promote zero-count rules

- Use `just ratchet-promote TOOL RULE` when a configured rule reaches zero.
- Require the adapter to enable the rule in the tool's durable enforcement configuration and verify the effective setting before removing its baseline entry.
- Do not store zero counts in baseline files.
