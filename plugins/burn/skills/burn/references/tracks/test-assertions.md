---
name: test-assertions
applies: has-tests
shard: file-set
invokes: "code:test-assertions {paths}"
evidence: "Each rewritten assertion shows the old and new form, and the changed tests pass."
---

Run `code:test-assertions` over the test files in the shard, rewriting weak or fragmented assertions into strict whole-value checks.

Run the changed tests before committing. A rewritten assertion that fails has found a real difference between the expected and actual value: revert that rewrite and return it as a finding rather than changing the expected value to match.

Commit the passing rewrites, citing a before and after example per file as the evidence. Return assertions that could not be made strict without a judgment call, such as values that are genuinely nondeterministic, as findings.
