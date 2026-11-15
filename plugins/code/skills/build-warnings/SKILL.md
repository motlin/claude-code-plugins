---
name: build-warnings
description: Make a build quiet by fixing the causes of the warnings it prints, one class at a time, with before and after counts from the same command as evidence. Covers compiler, linter and deprecation warnings, runtime warnings printed during tests, slow-test reports, and stray noise such as debug prints and unsilenced logs. Use when the user asks to clean up build or test warnings, deprecations, or noisy output, or when a caller such as burn runs it unattended.
---

# Build Warnings

A healthy build is quiet. Every warning the build prints trains readers to skim past the next one, and the one that matters, such as a deprecation that becomes a removal in the next upgrade, gets lost in the noise. Fix what the build warns about so that a new warning stands out.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/build-warnings/SKILL.md` file. The script below needs Python 3.9 or later.

## Arguments

- **Command:** the build and test command. Without one, find it the way burn does: git-test config (`git config --get-regexp '^test\.'`), `justfile` recipes, `package.json` scripts, a Makefile, then build files.
- **Scope:** a directory or file set to limit fixes to. Defaults to the whole repo. The build always runs whole, since that is how its output is produced.
- **`unattended`:** passed by callers such as `burn`. An unattended run asks the user nothing. Every question it would have asked becomes a queued finding instead (see Report).

## Measure once, then fix classes

Run the build once and save the grouped report:

```bash
python3 <plugin-root>/scripts/build_warnings.py --root . run --log <scratch>/before.log -- '<command>' > <scratch>/before.json
```

One quoted argument runs in a shell; several run directly. The report groups warning lines by kind (`compiler`, `lint`, `deprecation`, `runtime`, `slow-test`, `noise`, `other`) and by what they share: a rule id, a deprecated API, or a file. Each group has a count, the files it names, and `thirdParty`, which is true when every file lies outside the repository's control (`node_modules`, `site-packages`, `vendor` and the like). `--slow <seconds>` sets when a test duration counts as slow, 1 second by default.

The baseline must pass: if the build or tests fail, stop and report it, because this skill never fixes a broken build. Read `before.log` around each group's example as well, since a warning the script files as `other` may still be fixable. Work through the groups with the highest counts first, fixing one class at a time: one rule, one deprecated API, one source of noise.

## Fix the cause, never silence it

- **Compiler and lint warnings:** change the code the rule points at.
- **Deprecations:** move to the replacement the warning names. For a deprecated dependency, upgrade it to a version without the deprecation, within its current major version; a major upgrade is a finding, not a fix.
- **Runtime warnings in tests:** fix the code or test that triggers the warning, such as an unclosed resource or a missing await.
- **Noise:** remove leftover debug prints. For a log line that is legitimate but noisy in tests, capture it in the test that triggers it and assert on it, rather than lowering the level.

Never add suppression comments (`# noqa`, `// eslint-disable`, `@SuppressWarnings`, `#[allow]`), never lower a log level or a linter's severity, and never pass flags such as `-nowarn`, `-w` or `--no-warnings` to hide output. The only exception is a warning that comes from third-party code outside the repo's control and that no upgrade fixes: queue it instead of fixing it, with the dependency and its version.

Slow-test groups are not fixed here. Hand them to the `code:test-speed` skill, or queue them for it in an unattended run.

## Verify with the same command

After each class, rerun exactly the same command and compare:

```bash
python3 <plugin-root>/scripts/build_warnings.py --root . run --log <scratch>/after.log -- '<command>' > <scratch>/after.json
python3 <plugin-root>/scripts/build_warnings.py compare <scratch>/before.json <scratch>/after.json
```

`compare` prints each class's count before and after and exits 1 unless the total fell. Keep a fix only when the build and tests still pass and the class's count fell without another class growing. Otherwise revert it and record the failing output. Do not try a different fix for the same class: move on.

Commit once per class, with a message that names the class and its counts, such as "Replace the deprecated fake_old() call (DeprecationWarning, 4 to 0)". Follow the repository's commit conventions.

## Report

Report in the terminal, or return to the caller when unattended:

- each fixed class, with its count before and after from `compare`;
- each reverted fix, with the failing command and output;
- the classes left in place, and why.

An unattended run also returns its queued findings as task text the caller can append to `.llm/todo.md`: third-party warnings no upgrade fixes, major-version upgrades that a deprecation needs, and slow tests for `code:test-speed`. Each finding names the class, its count, the files, and the report's example line.
