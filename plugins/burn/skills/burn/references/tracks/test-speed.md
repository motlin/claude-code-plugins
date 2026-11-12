---
name: test-speed
applies: has-tests
shard: file-set
invokes: "code:test-speed {paths}"
evidence: "Before and after timings of the changed test files, measured the same way, plus the test count and coverage showing nothing was lost."
---

Time the test files in the shard first, with the suite's own timing output or by running each file alone, and work only on the slowest. Run `code:test-speed` over them.

Measure the after timings exactly as the before timings were measured, on the same machine in the same run. Commit only when the changed files are measurably faster and the tests still check everything they checked before. Paste both timings as the evidence. A change inside timing noise is not a gain: commit nothing.

Never delete a test to save time. Return candidates for deletion or for moving down the pyramid, each with the file, the test and the reason, as findings.
