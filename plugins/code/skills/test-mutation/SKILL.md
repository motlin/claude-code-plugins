---
name: test-mutation
description: Find bugs the test suite would miss by planting small mutants in covered, frequently changed code, then write tests that kill the survivors, keeping only tests that fail on a mutant and pass on the original. Use when the user asks for mutation testing, to check whether tests really catch bugs, or to strengthen weak tests for a file, a directory, or the whole repo, or when a caller such as burn runs it unattended.
---

# Test Mutation

Coverage shows which code ran; mutation testing shows whether any assertion would notice that code going wrong. Plant a small bug, run the tests, and if nothing fails, write the test that would have caught it. The mutation score is a signal, not a threshold: the output is tests that catch real bugs, not a number.

Load `code:test-assertions`, `code:test-data` and `code:test-speed` alongside this skill. New tests follow their shape: strict whole-value assertions, self-evidently fake literals, and extending an existing test file before creating one.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/test-mutation/SKILL.md` file. The scripts below need Python 3.9 or later.

## Arguments

- **Scope:** a file, a directory, or the whole repo (the default). Only files in scope get mutants.
- **`unattended`:** passed by callers such as `burn`. An unattended run asks the user nothing. Every question it would have asked becomes a queued finding instead (see Report).
- **Time budget:** 8 minutes of mutant runs by default. Stop planting new mutants when it runs out, and report what is left unvisited.

## Pick lines to mutate

Mutants only belong on lines the tests already run. A mutant on an uncovered line survives by definition, and that gap belongs to `code:test-coverage`. Measure coverage first, with the same script that skill uses, then rank files by churn and pick lines:

```bash
python3 <plugin-root>/scripts/coverage_baseline.py --root . run > "$WORKDIR/coverage.json"
python3 <plugin-root>/scripts/mutation_targets.py --root . targets "$WORKDIR/coverage.json" --paths <scope>...
```

Put `$WORKDIR` outside the repository so reports are never committed. The baseline must pass: if the suite fails before any change, stop and report it, because this skill never fixes a broken build.

`targets` skips vendored, generated and test files, files with no covered lines and files with no recent commits, and lists each skip with its reason. In each remaining file it picks at most 7 covered lines, one mutant per line, preferring relational operators, then logical connectors, then return values, then arithmetic. It never picks arid lines: logging, time and deadlines, metrics, tracing and pre-allocation. A mutant there is either equivalent or a bug nobody would write a test for.

## Plant the mutants

Use the ecosystem's mutation tool when the project has one, scoped to the picked lines or files:

```bash
python3 <plugin-root>/scripts/mutation_targets.py --root . detect
```

`detect` recognizes Stryker, PIT through Maven or Gradle, mutmut and cargo-mutants, and prints a command with `{file}`, `{lines}` or `{class}` placeholders. Never install a mutation tool or run its initializer: an interactive run asks first, and an unattended run writes mutants by hand.

Without a tool, write each mutant yourself on a picked line:

- flip a relational operator, such as `<` to `<=` or `==` to `!=`;
- swap a logical connector, `and` for `or`, or drop a negation;
- remove a statement;
- change a return value or a boundary constant;
- at most one realistic-bug mutant per function: the mistake a developer would plausibly make there, such as an off-by-one or a missed guard.

Apply one mutant, run the tests that cover the file, and restore the file byte for byte with `git checkout -- <file>` before applying the next. Never leave two mutants in place at once. A mutant the tests already catch is killed and needs nothing more.

## Settle each survivor

Every surviving mutant ends in exactly one of these states:

- **Killed** by a new test that passes the acceptance checks below.
- **Equivalent:** no input can produce a different return value, state, output or message. State the argument in one line. Claim equivalence only after a genuine attempt to write a killing test, because models over-claim it.
- **Queued** for the user as a judgment call: behavior whose intended result is unclear, or a mutant that exposes a likely bug in the original. An interactive run asks; an unattended run queues it.

Spend effort first on survivors in rules that matter: money, permissions, eligibility, safety and data loss.

## Write and accept the tests

Derive each expected value from intent: the function's name, its docs, the spec, or callers that rely on it. Never derive it by running the code and copying its output, because that locks in whatever the code does today, bugs included. When intent and the current behavior disagree, queue the finding instead of writing the test.

Keep a new test only when all of these hold. Check them in this order, and drop the test at the first failure:

- It passes on the original code.
- It fails with the mutant applied.
- It passes 5 repeated runs on the original. Repeating runs to find flakiness is measurement, not a retry.
- It kills at least one other mutant in the same function, or it fits naturally into an existing test. A test written to fit exactly one mutant is rejected.

Do not rewrite a rejected test and try again. Record the survivor as queued or skipped with the reason, and move on.

Never do any of these:

- edit or delete an existing test, except to add a case to a parameterized table;
- change production code;
- add suppression comments, skip or focus tests, or lower a mutation threshold.

## Gate the result

When the budget is spent or every survivor is settled, prove that every hand-written mutant was restored and only tests changed:

```bash
python3 <plugin-root>/scripts/mutation_targets.py --root . changed
```

It lists changed files that are not tests and exits 1 when there are any. Restore those files before going on. Then run the full suite once. If it fails, or no test was kept, commit nothing and report why. Otherwise commit the new tests together, following the repository's commit conventions.

## Report

Report in the terminal, or return to the caller when unattended:

- a table of every mutant: location, the change, its status (killed by an existing test, killed by a new test, equivalent, queued, not visited) and the killing test or the equivalence argument;
- the score before and after, as killed over killed plus survived, excluding equivalent mutants;
- each file skipped by `targets`, with its reason.

An unattended run also returns its queued findings as task text the caller can append to `.llm/todo.md`: survivors that need a judgment call, mutants that expose a likely bug, whether to add a mutation tool, and code where intent is too unclear to test. Each finding names the file, the symbol, the mutant and the evidence.
