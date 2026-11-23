---
name: retry-removal
applies: any
shard: directory
invokes: "a retry and backoff audit over {paths}"
evidence: "Each removal cites the retry it removes and the root cause it fixed, with the command output that showed the failure before the fix and its absence after, or a passing run that exercises the path without the retry."
---

Find every retry in the shard: retry loops, backoff, retry counts and flags passed to tools or clients, retry decorators and helpers, re-running a failed command, and sleep-then-poll waits that stand in for a real readiness signal. Retries hide the cause of a failure instead of fixing it.

For each one, find out what failure it was added to absorb: read the code around it, `git log -S` for the commit that added it and that commit's message, and any linked issue. When the cause is clear and fixable in the code, such as a race with a readiness signal to wait on, a missing ordering, or a resource that is never released, fix the cause and remove the retry in the same commit, one commit per retry. Commit only when you can show the fixed path working without the retry.

Never add a retry, never raise a timeout to compensate, and never remove a retry without fixing its cause. When the cause is outside the code, such as a flaky network, an external service, or a test environment you cannot reproduce, return a finding with the retry's location, the commit that added it, and the likely cause to trace. With nothing fixed, commit nothing.
