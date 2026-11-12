---
name: mutation
applies: has-tests
shard: directory
invokes: "code:test-mutation {paths} unattended"
evidence: "Each new test cites the mutant it kills, with the test run failing on the mutant and passing on the original."
---

Run `code:test-mutation` with the shard as its scope, unattended. Keep its working files, such as the coverage report, outside the worktree so they are never committed.

Commit only when its gate passes: `mutation_targets.py changed` lists nothing and the full suite passes. Paste the mutant table and, for each new test, the failing run on its mutant and the passing run on the original as the evidence. With no test kept, commit nothing.

Return the skill's queued findings as findings: survivors that need a judgment call, mutants that expose a likely bug in the original, and code whose intent is too unclear to test.
