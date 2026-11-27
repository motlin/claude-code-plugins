---
name: template-sync
applies: has-template
shard: whole-repo
invokes: "each owning template's sync-template command, applied as changes instead of tasks, over {paths}"
evidence: "Each change names the template, the managed file and the sync-template rule it follows, and shows the file now matches the template or differs only in a way that command allows; the build and tests pass after it."
---

Bring the repository in line with the project templates that own it. A template is a sibling repository beside this one, such as `project-template` or a language template like `typescript-template`, whose `.claude/commands/sync-template.md` describes the files it manages and whose `.llm/projects.yaml` lists the projects it syncs: by `own`, `forks` or `nested` entries, or by `scan` with `skip`. Find every template that lists this repository; base and language templates often both do.

Read each owning template's `sync-template.md` and the `.claude/includes/sync-*.md` files it pulls in, and follow its rules for this one repository, with the template's files as the source of truth. Where it would create a task for a mismatch, make the change on your branch instead, one commit per managed file or per closely related set, naming the template. Respect what the commands say about ownership: a language template's version of a path overrides the base template's, a derived template keeps its documented specializations, forks keep upstream-specific config, and files the command says stay in the template are never copied. Keep project-specific additions the command says to preserve, such as extra ignore patterns or `.gitattributes` rules.

Never run a sync command itself and never write to a template or to `.llm/todo.md` directly, since sync commands write tasks into other repositories. Change only this repository, and commit only when the build and tests pass.

When this repository is itself a template, also do what its sync command asks of a template: diff its shared `sync-*.md` includes against `project-template`'s, which are the source of truth, and make them byte-identical; and look through the projects it owns for general improvements that belong in the template.

Return as findings: mismatches that need a decision the command leaves to the user, such as a major version bump or a conflicting project-specific rule; improvements this repository has that its template lacks, such as a better ignore pattern, hook or CI job, naming the template path to change; and template rules that no longer fit any project they own. With everything already in sync, commit nothing.
