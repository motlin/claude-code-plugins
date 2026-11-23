---
name: skill-review
applies: any
shard: skill
invokes: "the {paths} skill, in review mode, over the whole repository"
evidence: "Each change cites the rule in the skill it applies, and the build and tests pass after it."
---

Run one installed skill that preflight judged relevant to this repository, as a reviewer of the code that already exists. The shard is the skill's name. Load the skill and read its rules first, then apply them across the repository.

Apply only changes the skill states plainly and that need no decision from the user, such as a required ordering, a naming rule or a pattern the skill says to replace. When the skill describes a tool that rewrites code, such as an OpenRewrite recipe, prefer running that tool over editing by hand. Group related edits into one commit per rule or per closely related set, and commit only when the build and tests pass.

Return every other place the code breaks one of the skill's rules as a finding with the file, the rule and the proposed change. With nothing applied, commit nothing.
