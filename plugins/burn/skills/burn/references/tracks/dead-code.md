---
name: dead-code
applies: any
shard: directory
invokes: "code:dead-code {paths} unattended"
evidence: "Each removal cites the detector line reporting it, or dead_code.py refs output with the verdict unreferenced."
---

Run `code:dead-code` with the shard as its scope, unattended. References are searched across the whole worktree, never only the shard, because code outside the shard may be the only caller.

Commit only high-tier removals that pass the build, type check and tests, one commit per category as the skill describes. Paste each removal's detector line or `refs` output as the evidence. A batch the skill reverted stays reverted: report it, do not try again.

Return medium and low candidates as findings, with the removal you would make and the tests that exercise only that code. Drop detectors worth adding: they belong in the dead-code skill, not this repository.
