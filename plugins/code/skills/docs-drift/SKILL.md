---
name: docs-drift
description: Find documentation that disagrees with the code, such as renamed paths, missing recipes, stale versions and outdated behavior claims, apply only mechanical one-to-one fixes, and propose the rest. Use when the user asks to check, audit or fix docs, READMEs, CLAUDE.md, AGENTS.md or SKILL.md files against the code, or to find stale or broken documentation, or when a caller such as burn runs it unattended.
---

# Docs Drift

Docs drift when code changes and the prose does not follow. A wrong doc is worse than a missing one, because readers and agents act on it. Find the claims the code contradicts and fix them without rewriting anything else.

Resolve `<plugin-root>` first: in Claude Code use `${CLAUDE_PLUGIN_ROOT}`; in Codex use the plugin root that contains this `skills/docs-drift/SKILL.md` file. The script below needs Python 3.9 or later.

Prior art worth reading for hard cases: drift-doc (<https://github.com/raphabruno7/drift-doc>) and doc-drift-detector (<https://github.com/borghei/Claude-Skills/blob/main/engineering/doc-drift-detector/SKILL.md>).

## Arguments

- **Scope:** by default, the docs that name a file changed since the merge-base with the upstream branch. `all` checks every doc, optionally limited to directories; burn passes `all` with a path shard.
- **`unattended`:** passed by callers such as `burn`. An unattended run asks the user nothing. Every proposed change becomes a queued finding instead (see Report).

## List the docs

```bash
python3 <plugin-root>/scripts/docs_drift.py --root . docs --since "$(git merge-base HEAD @{upstream})"
python3 <plugin-root>/scripts/docs_drift.py --root . docs <directory>...
```

The doc set is README files, CLAUDE.md, AGENTS.md, SKILL.md and command files, outside vendored directories. Code comments are docs too, but the script does not list them: check comments in files within scope by hand, for the same kinds of claims. A doc nobody scans drifts unnoticed, so when the project keeps docs elsewhere, such as a `docs/` site, add them to the list yourself.

## Run the pre-pass

```bash
python3 <plugin-root>/scripts/docs_drift.py --root . claims <doc>...
```

The pre-pass is deterministic, so you judge only what it flags rather than reading every doc end to end. It checks:

- link targets and path-like code spans against the tree, resolved from the doc's directory and every directory above it, and against git renames, which catches moved and deleted files;
- `just` recipes and npm scripts named in code against the `justfile` and `package.json`, in both directions: recipes the docs name that do not exist, and recipes no doc names;
- `name@version` against the project manifest;
- hard-coded counts such as "12 plugins".

Each claim has a status:

- `renamed`, or `contradicted` with a `replacement`: a mechanical fix with a known one-to-one replacement.
- `contradicted` with no replacement: the code disagrees, and fixing it needs judgment. Some of these are examples about another project, which are fine as written.
- `check`: a count to verify, or a recipe no doc mentions.

## Check the rest

Beyond the flagged claims, read the behavior claims in scope: what a command does, its flags and defaults, what a function returns, what the configuration accepts. Compare each with the code, `--help` output or the parser. Verify links with `lychee --offline --include-fragments <doc>...` when lychee is installed.

Run a fenced command from a doc only when it is read-only, with a timeout and no network, and never one marked with a skip tag such as `<!-- docs-drift: skip -->`. Give every claim you checked a verdict of contradicted, unverifiable or OK, with the evidence: the file and line, or the command output.

## Fix only what is mechanical

- Apply a fix on your own only when it is a one-to-one replacement: a renamed path, a renamed flag or recipe with a known successor, a stale version.
- Replace a hard-coded count with a pointer to where the number comes from, such as "the plugins listed in `marketplace.json`", rather than updating the number.
- Everything else is a proposed change: an interactive run shows it and asks, and an unattended run queues it.

Never do any of these:

- change source code to match a doc;
- rewrite prose the code does not contradict;
- restructure or reword a doc beyond the contradicted words.

## Gate the result

Rerun the pre-pass with `--strict` on every doc you changed. It exits 1 while any mechanical fix remains:

```bash
python3 <plugin-root>/scripts/docs_drift.py --root . claims --strict <doc>...
```

Then commit the fixes, following the repository's commit conventions. When nothing was fixed, commit nothing.

## Report

Report in the terminal, or return to the caller when unattended:

- each fix, with the claim, its replacement and the evidence;
- each contradicted claim left for a human, with the evidence;
- the docs checked, so a reader knows what was not.

An unattended run also returns its queued findings as task text the caller can append to `.llm/todo.md`: proposed rewrites of contradicted behavior claims, recipes no doc mentions, and counts that need a source. Each finding names the doc, the line, the claim and the evidence.
