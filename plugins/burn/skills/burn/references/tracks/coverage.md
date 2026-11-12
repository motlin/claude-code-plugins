---
name: coverage
applies: has-tests
shard: directory
invokes: "code:test-coverage {paths}"
evidence: "The coverage_baseline.py compare output shows a measured gain for every file the branch touches."
---

Run `code:test-coverage` with the shard as its scope. Keep its working files, such as the before and after coverage reports, outside the worktree so they are never committed.

Commit only when its final gate passes: `coverage_baseline.py compare` exits 0 against the baseline taken in this worktree. Paste the compare output as the evidence. Without a measured gain, commit nothing.

Return the skill's queued findings as findings: a missing coverage provider, untested code that looks dead, and code that needs a design change before it can be tested.
