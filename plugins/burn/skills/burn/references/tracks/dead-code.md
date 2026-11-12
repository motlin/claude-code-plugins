---
name: dead-code
applies: any
shard: directory
invokes: "code:dead-code {paths} unattended"
evidence: "Each removal cites the detector line reporting it, or dead_code.py refs output with the verdict unreferenced."
---

Run `code:dead-code` with the shard as its scope, unattended. References are searched across the whole worktree, never only the shard, because code outside the shard may be the only caller.

Commit only high-tier removals that pass the build, type check and tests, one commit per category as the skill describes. Paste each removal's detector line or `refs` output as the evidence. A batch the skill reverted stays reverted: report it, do not try again.

Return the skill's queued findings as findings: medium and low candidates, tests that exercise only dead code, and detectors worth adding.
