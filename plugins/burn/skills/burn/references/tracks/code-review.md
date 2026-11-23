---
name: code-review
applies: any
shard: directory
invokes: "/code-review {level} {paths} --fix"
evidence: "Each change cites the finding code-review reported for it."
---

Review the existing code in the shard, not a diff: the target is the directory itself. The review verifies its own findings at the high level, so do not add a second review pass over its output.

Commit the fixes `--fix` applied that you agree with, one commit per finding or per closely related group. Revert any applied fix whose finding you cannot confirm by reading the code.

Return a finding the review reported but you chose not to fix only when it is a design question, with the file, the symbol, the review's reasoning and the change you would build. Drop style nits and speculative findings.

If `/code-review` cannot be invoked from this agent, read its SKILL.md and follow it directly over the shard.
