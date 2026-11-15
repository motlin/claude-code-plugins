---
name: plugin-quality
applies: is-plugin-repo
shard: directory
invokes: "plugin-and-skill-dev:writing-instructions and anthropic-skills:skill-creator over {paths}"
evidence: "Each edit cites the writing-instructions or skill-creator rule it applies, or the claude plugin validate error it fixes, and claude plugin validate passes on the shard after the change."
---

Review and improve the `SKILL.md`, agent and command files in the shard. The shard is one plugin directory, or the whole repo when it has no plugin directories. Load `plugin-and-skill-dev:writing-instructions` and `anthropic-skills:skill-creator` first, and judge each file against their rules. When either skill is not available, read its `SKILL.md` from the installed plugins instead.

Run `claude plugin validate <shard>` before and after the changes when the `claude` CLI is available. Fix the errors it reports, and never commit a change that makes it fail.

Apply only body edits whose rule leaves one clear wording: formatting, privacy, structure, stale or duplicated instructions, and broken references between files. Group related edits into one commit per file or per closely related set. Never change a plugin's version number.

Never apply a rewrite of a `description` or other trigger text, because it changes when the skill loads. Return each as a finding with the file, the rule, the current text and the proposed wording, so the user decides.
