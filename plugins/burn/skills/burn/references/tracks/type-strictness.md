---
name: type-strictness
applies: has-type-checker
shard: directory
invokes: "the project's type checker over {paths}"
evidence: "The type checker's output for the shard before and after, run with the same command and config, showing no new errors, plus the passing build and tests."
---

Tighten types in the shard so the type checker catches more. Replace `any`, `unknown` casts, `# type: ignore`, `@ts-ignore`, `@SuppressWarnings("unchecked")`, raw generic types, unchecked casts and missing annotations with the real types, read from how the values are built and used.

Use the project's own checker and config: `tsc --noEmit`, mypy, pyright, the Java or Kotlin compiler with its lint flags, or `go vet`. Never loosen the config or add a suppression to get a change through. A stricter config flag is in scope only when the whole repository passes with it after your changes, not just the shard.

Commit one file or one closely related group per commit, only when the checker reports no new errors and the build and tests pass. When the real type is unclear, or tightening it would change runtime behavior, leave the code and return a finding with the location and what the type depends on. With nothing tightened, commit nothing.
