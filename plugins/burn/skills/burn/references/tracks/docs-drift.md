---
name: docs-drift
applies: any
shard: directory
invokes: "code:docs-drift all {paths} unattended"
evidence: "Each fix cites the docs_drift.py claim it resolves, and claims --strict exits 0 on every changed doc."
---

Run `code:docs-drift` over every doc in the shard, unattended. It applies only mechanical one-to-one fixes: renamed paths, renamed flags or recipes with a known successor, stale versions, and hard-coded counts turned into pointers.

Commit only when `docs_drift.py claims --strict` exits 0 on every doc the branch changes. Paste the pre-pass entry for each fix as the evidence. Never change source code to match a doc. With no mechanical fix, commit nothing.

Return the skill's queued findings as findings: contradicted behavior claims with the evidence and a proposed wording, recipes no doc mentions, and counts that need a source.
