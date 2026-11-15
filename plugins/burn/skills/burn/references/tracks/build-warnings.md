---
name: build-warnings
applies: any
shard: whole-repo
invokes: "code:build-warnings {paths} unattended"
evidence: "The build_warnings.py compare output for the same command before and after, showing the total fell, plus the passing build and tests."
---

Run `code:build-warnings` unattended with the test command from preflight. The build always runs whole: one run of the command before any change gives the baseline report, and every fix is measured by rerunning exactly that command.

Fix causes, never silence them: no suppression comments, no lowered log levels, no flags that hide warnings. Commit only classes whose count fell while the build and tests stayed green, one commit per class as the skill describes. Paste the `compare` output as the evidence. If the total did not fall, commit nothing.

Return the skill's queued findings as findings: third-party warnings no upgrade fixes, deprecations that need a major-version upgrade, and slow tests for `code:test-speed`.
