---
name: dead-code
description: Find and remove unused code, files, exports and dependencies, with detector output or a zero-reference grep as evidence for every removal, and leave anything uncertain for a human. Use when the user asks to find or delete dead, unused or unreachable code, unused dependencies or exports, for a file, a directory, or the whole repo, or when a caller such as burn runs it unattended.
---

# Dead Code

Delete code nothing uses. Dead code costs reading time, review time and build time, and it misleads: a reader assumes it matters. A wrong deletion costs more than a missed one, so every removal carries evidence, and anything a tool cannot see into stays.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/dead-code/SKILL.md` file. The script below needs Python 3.9 or later.

## Arguments

- **Scope:** a file, a directory, or the whole repo (the default). Only code in scope is removed, but references are always searched across the whole repo.
- **`unattended`:** passed by callers such as `burn`. An unattended run asks the user nothing. Every question it would have asked becomes a queued finding instead (see Report).

## Detect from the entry points

Analyze reachability from the program's entry points, not one symbol at a time. Whole-graph analysis finds chains of code that only dead code calls; Meta's SCARF removed about 50% more once it switched to it (<https://engineering.fb.com/2023/10/24/data-infrastructure/automating-dead-code-cleanup/>). Find the detectors the project already has:

```bash
python3 <plugin-root>/scripts/dead_code.py --root . detect
```

`detect` recognizes these and prints their commands:

- knip, run twice: by default, then with `--production`, which also reports code that only tests use;
- vulture for Python;
- `deadcode -test` for Go, with `-whylive` to show why a symbol it keeps is alive;
- cargo-machete for unused Rust dependencies;
- OpenRewrite's private-only `RemoveUnused*` recipes for Java, through the Maven rewrite plugin.

The baseline must pass: if the build or tests fail before any change, stop and report it, because this skill never fixes a broken build. Never install a detector or add it to the project's dependencies: an interactive run asks first, and an unattended run queues the suggestion and falls back to the method below.

Without a detector, list candidates from the language server's find-references, or by reading the scope for definitions, and check each one with a repo-wide grep that includes string matches:

```bash
python3 <plugin-root>/scripts/dead_code.py --root . refs <symbol> --definition <file>:<line>
```

`refs` greps tracked files for the symbol as a whole word, string matches included, leaves out the definition, and splits the rest into code and tests. Its verdict is `unreferenced`, `test-only` or `referenced`. A string match counts as a reference until you have read it and shown it names something else.

## Fix the configuration before ignoring anything

A detector that reports live code as dead usually lacks an entry point or a framework plugin. Fix its configuration first: entry files, workspaces, framework plugins. Record a genuine exception in the tool's own allowlist (knip config, vulture whitelist, cargo-machete metadata), never in this skill and never as a suppression comment (<https://knip.dev/guides/handling-issues>). In an unattended run, configuration changes go in their own commit, so a reviewer can judge them apart from the deletions.

## Sort candidates into tiers

- **High:** the detector reports it and `refs` says `unreferenced`.
- **Medium:** the detector alone reports it, or `refs` says `test-only`.
- **Low:** anything a static tool cannot see into: exported or public API, framework entry points, decorators and routes, dependency injection, reflection, code generation, plugin registries, and code with side effects at load time.

Remove only high candidates on your own. Code that only tests use counts as dead together with its tests, as in Google's Sensenmann (<https://testing.googleblog.com/2023/04/sensenmann-code-deletion-at-scale.html>), but deleting tests needs approval: an interactive run asks, and an unattended run queues the finding. Medium and low candidates are questions for the user in an interactive run and queued findings in an unattended one.

## Remove in passes

Remove in this order: whole files, then exports and symbols, then dependencies. Removing a file can orphan the exports it used, and removing code can orphan a dependency, so rerun the detector after each pass and stop when it finds nothing new.

After each batch, run the build, the type checker and the tests. A batch that fails any of them is reverted and recorded with the failing output. Do not try a smaller batch or a different fix: move on.

Commit once per category: files, exports and symbols, dependencies, and configuration. Each message says why the code is dead, such as "no references outside its definition" or "knip reports the dependency unused". Follow the repository's commit conventions.

Never do any of these:

- remove code `refs` reports as `referenced` without reading every match;
- delete a test that covers live code;
- add suppression comments or lower a detector's strictness to quiet it;
- change behavior while deleting, such as inlining or renaming what remains.

## Report

Report in the terminal, or return to the caller when unattended:

- each removal, with its tier and evidence: the detector's line for it, or the `refs` output;
- each reverted batch, with the failing command and output;
- candidates left in place, with their tier and why.

An unattended run also returns its queued findings as task text the caller can append to `.llm/todo.md`: medium and low candidates, tests that only exercise dead code, and detectors worth adding. Each finding names the file, the symbol and the evidence.
