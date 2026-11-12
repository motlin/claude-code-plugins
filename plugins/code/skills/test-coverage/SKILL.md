---
name: test-coverage
description: Raise measured test coverage where it matters most, by writing tests for the least-covered, most-changed code and keeping only tests that pass strict acceptance checks. Use when the user asks to grow, raise, or improve test coverage for a file, a directory, or the whole repo, or when a caller such as burn runs it unattended.
---

# Test Coverage

Write tests that cover behavior nobody tested, in the code that changes most. Coverage is the measure, not the goal: a test that raises the number without checking behavior is worse than no test, because it hides the gap.

Load `code:test-assertions`, `code:test-data` and `code:test-speed` alongside this skill. New tests follow their shape: strict whole-value assertions, self-evidently fake literals, and extending an existing test file before creating one.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/test-coverage/SKILL.md` file. The scripts below need Python 3.9 or later.

## Arguments

- **Scope:** a file, a directory, or the whole repo (the default). Only files in scope are ranked.
- **`unattended`:** passed by callers such as `burn`. An unattended run asks the user nothing. Every question it would have asked becomes a queued finding instead (see Report).

## Measure the baseline

Detect the coverage tooling, then run it once and save the normalized report:

```bash
python3 <plugin-root>/scripts/coverage_baseline.py --root . detect
python3 <plugin-root>/scripts/coverage_baseline.py --root . run > "$WORKDIR/coverage-before.json"
```

`detect` recognizes Vitest, Jest, pytest-cov, Go, cargo tarpaulin, and JaCoCo through Maven or Gradle, and prints the command it would run. Pass `--ecosystem <name>` to `run` to pick one when several are detected. Put `$WORKDIR` outside the repository so reports are never committed.

When the project uses a tool `detect` does not know, or needs different flags, run the project's own coverage command and normalize what it writes with `coverage_baseline.py parse --format lcov|cobertura|gocover|jacoco <report>...`. When the project has no coverage provider at all, add one temporarily, and revert the dependency and lockfile changes before committing. An interactive run asks before adding one; an unattended run queues the question and stops.

The baseline must pass. If the suite fails before any change, stop and report it: this skill never fixes a broken build.

## Pick targets

Rank files by churn times the uncovered share:

```bash
python3 <plugin-root>/scripts/churn_rank.py "$WORKDIR/coverage-before.json" --root . --paths <scope>...
```

The script skips generated, vendored, test, trivial and fully covered files, and files with no commits in the window (`--since`, default one year), and lists each skip with its reason. Work through the targets from the top.

Within a target file, the unit of work is the smallest public function or class that encloses uncovered or partially covered lines, about 50 lines at most. Split a larger unit by its public methods. Show the agent writing the tests that unit's source with its coverage tags, plus the existing test file for it so new tests match its style:

```bash
python3 <plugin-root>/scripts/coverage_baseline.py --root . annotate "$WORKDIR/coverage-before.json" <path>
```

`!` marks an uncovered line and `~` a line with an untaken branch. Without these hints, models write many more tests and most of them add no coverage.

## Write the tests

Test the unit's public behavior: given these inputs, this output or this observable effect. Add new cases to an existing test file that already covers the area; create a test file only when none fits, at the lowest level of the pyramid that proves the behavior.

Never do any of these:

- write a test without assertions, a test that only calls getters, or a snapshot-only test;
- mock the unit under test;
- add coverage-ignore comments, or lower a coverage threshold;
- edit or delete an existing test;
- change production code, except a tiny refactor that makes a unit testable, which the report flags.

When covering a line would need one of these, skip the target and record why.

## Accept or reject each test

Keep a new test only when all of these hold. Check them in this order, and drop the test at the first failure:

- It builds.
- It passes.
- It passes 5 repeated runs, plus a random-order or isolated run where the framework supports one. Repeating runs to find flakiness is measurement, not a retry.
- It lowers the target's uncovered or partially covered lines: rerun coverage for the test file and check with `coverage_baseline.py compare`.
- It is not a duplicate of an existing test: it checks something no existing test already checks.

Do not rewrite a rejected test and try again. Record the target as skipped with the reason (randomness, I/O, unreachable code, a failed acceptance check) and move on to the next target. Studies of generated tests found that only about a quarter raise coverage, so rejection is the normal case and these checks do real work.

## Gate the result

When the targets are done, run the full suite and coverage again, then compare against the baseline:

```bash
python3 <plugin-root>/scripts/coverage_baseline.py --root . run > "$WORKDIR/coverage-after.json"
python3 <plugin-root>/scripts/coverage_baseline.py compare "$WORKDIR/coverage-before.json" "$WORKDIR/coverage-after.json"
```

`compare` exits 1 when no line or branch gained coverage, or when the total of covered lines dropped. Without a measured gain, the run failed: commit nothing and report why. With a gain, commit the new tests together, following the repository's commit conventions.

## Report

Report in the terminal, or return to the caller when unattended:

- total coverage before and after, and per-file before and after for every changed file, from `compare`;
- each test added, with the target unit it covers;
- each target skipped, with its reason;
- any testability refactor made to production code.

An unattended run also returns its queued findings as task text the caller can append to `.llm/todo.md`: whether to add a coverage provider, untested code that looks dead, code that needs a design change before it can be tested, and any other judgment call. Each finding names the file, the symbol and the evidence.
