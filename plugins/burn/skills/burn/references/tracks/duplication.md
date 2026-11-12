---
name: duplication
applies: has-tests
shard: directory
invokes: "goal-sloc {paths}"
evidence: "Each merge names the duplicated blocks it replaces, with their files and lines, and the tests pass before and after."
---

Run `goal-sloc` with the shard as its scope, limited to its de-duplication rule: repeated blocks become one parameterized helper, and near-identical files become one. Skip its other reduction levers, such as dead-code removal, which belongs to the dead-code track, and comment or formatting trims, which are not real work.

Merge only genuine duplication: blocks that share behavior and would change together. Code that looks alike but serves different purposes stays apart. Keep behavior unchanged, and run the tests before and after each merge.

Commit each merge on its own, citing the duplicated locations and the passing tests as the evidence. With no merge worth making, commit nothing. Return duplication that needs a design decision, such as two modules that should share an abstraction, as findings.
