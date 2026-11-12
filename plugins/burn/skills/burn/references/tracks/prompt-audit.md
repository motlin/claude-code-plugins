---
name: prompt-audit
applies: has-prompts
shard: directory
invokes: "/doctor prompt-audit {paths}"
evidence: "Each edit cites the audit finding it applies: the file, the line and the dated pattern the report named."
---

Audit the prompt text in the shard: skills, agents, commands and `CLAUDE.md` or `AGENTS.md` files. The shard is one plugin directory, or the whole repo when it has no plugin directories. Audit only files inside the shard, never user-level or installed-plugin files the audit also inventories.

When the audit runs through `claude -p "/doctor prompt-audit ..."`, that command exits before its background reviewers finish, so its own output misses their findings. Wait for the reviewers, then read their saved output files from the run's transcript before acting on the report. If `/doctor prompt-audit` cannot be invoked at all, follow the prompt-audit guide in the `claude-api` skill (`shared/prompt-audit.md`) directly over the shard.

Apply only findings that need no user decision: dated wording, stale narrative, duplicated or contradicted instructions with one clear survivor, and examples that no longer match the text. Group related edits into one commit per file or per closely related set.

Never edit a finding that changes a safety gate or a global rule, such as when to ask before a destructive action, retry and restart limits, staging and commit rules, or anything in a user-level `CLAUDE.md`. Return each as a finding with the file, the line, the audit's reasoning and the proposed wording, so the user decides.
