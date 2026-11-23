---
name: plugin-quality
applies: has-prompts
shard: directory
invokes: "plugin-and-skill-dev:writing-instructions, anthropic-skills:skill-creator and plugin-authoring over {paths}"
evidence: "Each edit cites the writing-instructions, skill-creator or plugin-authoring rule it applies, or the claude plugin validate error it fixes, and claude plugin validate passes on the shard after the change."
---

Review and improve the `SKILL.md`, agent, command and hook files in the shard. The shard is one plugin directory, a project's `.claude/` directory, or the whole repo when it has neither. Load `plugin-and-skill-dev:writing-instructions` and `anthropic-skills:skill-creator` first, and judge each instruction file against their rules. When the shard has hooks, a status line, a theme or another mod, also load `plugin-authoring` and judge those files against it. When a skill is not available, read its `SKILL.md` from the installed plugins instead, and skip it when it is not installed at all.

When the shard is a plugin and the `claude` CLI is available, run `claude plugin validate <shard>` before and after the changes. Fix the errors it reports, and never commit a change that makes it fail.

Apply only body edits whose rule leaves one clear wording: formatting, privacy, structure, stale or duplicated instructions, and broken references between files. Group related edits into one commit per file or per closely related set. Never change a plugin's version number.

Never apply a rewrite of a `description` or other trigger text, because it changes when the skill loads. Return each as a finding with the file, the rule, the current text and the proposed wording, so the idea phase builds it for the user to decide.
