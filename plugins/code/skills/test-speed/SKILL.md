---
name: test-speed
description: Keep test suites fast by preferring fewer, fuller tests, pushing logic tests down the pyramid, and cutting setup, imports, and real waits without losing coverage. Use when the user asks to speed up, consolidate, or rebalance tests; when writing a new test during feature work (extend an existing test first); and after a large multi-task run or branch that added many tests or made the suite slower.
---

# Test Speed

Agents add a test or two with every change and rarely add assertions to an existing test, so after a long run of tasks a suite grows by hundreds of tests, each paying its own setup, and drifts toward slow end-to-end tests. Every extra second is paid on every commit gate and every CI run. Even 1% growth deserves attention because it compounds.

Load the `code:test-assertions` skill alongside this one. Folding tests together almost always means replacing scattered checks with one strict whole-value assertion, and that alone often nudges coverage up.

## When writing a test during feature work

Extend an existing test before adding a new one. Look for a test that already builds the same setup (the same fixture, database, server, render, command invocation) or exercises the same subject, and add the new case there: a new field in its expected value, another row in its table of cases, another step in its scenario.

Red/green still applies. The red step is the extended test failing on its new expectation, then the implementation turns it green.

Add a new test only when no existing test fits, and write it at the lowest level of the pyramid that proves the behavior. Pure logic gets a unit test over the function, not a browser run or a full command invocation. If logic is tangled into a component or handler, extract the pure function and test that.

## When running a speed pass

Run the pass directly when invoked. The user queues it as a task themselves when they want one.

### Measure without running the suite twice

Running the suite once just to measure doubles the cost of the thing being fixed. Take timings from runs that happen anyway:

- Read the durations the normal gate already prints or saves: the test runner's summary line, per-file times from a verbose or JSON reporter, surefire XML reports, saved precommit or git-test logs.
- If the project records nothing usable, configure the runner to write per-file timings to a stable path on every run (a JSON reporter output file, surefire reports kept in place) and include that in the pass, so the next pass gets numbers for free. The `build:test-setup` skill is the place to make git-test gates keep these logs.

Record the baseline: total duration, test file count, test count, and the slowest files.

Run coverage twice for the whole pass, once on the starting commit and once at the end. Skip it when the project has no coverage tooling.

### Find where the time goes

Rank files by duration and by tests per expensive setup, and work from the slowest down. Note where the runner splits time (tests, import, transform, environment, setup); a large import share points at file merging and module loading rather than test bodies.

### Apply the techniques

Fewer, fuller tests:

- Merge small tests that share setup into one test that builds the setup once and checks the whole result, so the database, server, render, or command runs once instead of once per case.
- Fold scenario tests into shared contract or parameterized tests when a test hierarchy or case table already exists.
- Merge tiny test files that import the same heavy modules, so imports and transforms happen once per worker.

Push down the pyramid:

- Rewrite end-to-end and browser tests that check pure logic as unit tests over that logic, extracting pure functions from components or handlers when needed.
- Keep end-to-end tests only for what lower-level tests cannot prove, such as wiring, routing, and real integration boundaries. Judge which survive case by case.

Build expensive fixtures once:

- Generate keys, parse large fixtures, and load heavy modules once per file or per worker rather than in every `beforeEach` or test.
- Build an expensive base state once (a fully migrated database, a seeded repository) and hand each test a cheap copy of it, keeping a test or two that exercise the real from-scratch path.

Remove real waits:

- Use fake timers instead of real ones, and wait for a condition instead of sleeping a fixed time.
- Scale timeouts, retry delays, and rate limits down in tests, keeping their ratios meaningful.
- Use the smallest data that proves the behavior (100 rows, not 50,000).
- Replace a test that waits for slow behavior to unfold with a direct check of the mechanism behind it, red-checked against the broken version.

Runner config levers:

- Share module graphs or workers between files where isolation is not needed (for example vitest `isolate: false`), keeping files that need isolation in a separate isolated project.
- Enable parallel execution where it is off (for example JUnit parallel execution, or more forks).
- Remove duplicate work in the gate, such as running the whole suite twice for a matrix or type-checking twice.
- Measure each lever on its own before keeping it; config changes can surface shared-state bugs.

### Hold the line

- Never weaken an assertion. Every merged assertion's intent survives, written as a strict whole-value check.
- Never delete or skip a test unless its assertions live on elsewhere.
- Never raise a timeout to make a test pass. Speed comes from less work, not more patience.
- Never change production behavior. Extracting a pure function to enable push-down is fine.
- Line coverage must not drop by 1 percentage point or more, and should normally not drop at all. Explain any drop.

### Finish

Make one commit if possible, splitting only when the diff is huge and each commit stays green. The commit message says the suite was sped up, with at most a ballpark such as "about 20% faster", since exact timings are machine-specific.

Report in the terminal: total duration, test file count, test count, and line coverage before and after; the slowest files before and after; and slow tests left unchanged, with the reason.

## After a large run of tasks

When a branch or multi-task run added many tests or made the suite measurably slower, a speed pass is worth considering. Weigh it against how much the suite grew and suggest it, or queue it, when the growth is meaningful.
