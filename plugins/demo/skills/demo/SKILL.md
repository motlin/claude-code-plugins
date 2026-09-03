---
name: demo
description: 'Demo working software by showing real data crossing real IO boundaries — the request on the wire, the SQL that ran, the rows and DDL on disk, the command and its captured output — with every byte recorded by a capture script rather than written by hand. Use when asked to demo, to "show me it working", "I need to see it", "prove it", or to walk through what was built, and before opening a pull request or calling work done.'
---

# Demo

A demo answers one question: does the system really do this? Code is not the answer,
and neither is a summary of the code. The answer is data — a real request, a real row,
a real file, a real command and what it printed.

## What counts as a demo

Show the data crossing the boundaries of the system, in the order it crosses them.
Everything else is commentary.

- **In at the edge** — the actual HTTP request and response on the wire, the CLI invocation, the file a user would really drop in, the message off the queue
- **Through the work** — the command that does the thing, run for real
- **Into storage** — the SQL that executed, the rows before and after, and the on-disk shape: DDL, schema dump, file layout, bytes
- **Out to the human** — the page, the terminal, the report, the screenshot

Reading code aloud is not a demo. Neither is a table of what changed, a test-passed
count, or a paragraph beginning "the system now correctly". Those describe. A demo shows.

## Capture, never author

Every byte of output in a demo comes from a file a script wrote while the command ran.
Write the command; let the tool capture the result. Never retype output, tidy it,
reconstruct it from memory, or predict what it would say.

The rule: if it was typed, it is prose. If it is evidence, it came out of `demo-capture`.

### Record each step

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/demo/SKILL.md` file.

```console
<plugin-root>/scripts/demo-capture --demo <slug> \
  --title 'Import one real Fidelity export' \
  --why 'This is the only way data enters the system.' \
  --look-for 'Four transactions in, two of them paired into one move.' \
  -- ./bin/run.js import ~/Downloads/fidelity-2026-08.csv
```

Use `--sh '<string>'` instead of `-- <argv>` when the step is a pipeline; the string is
what runs and what gets displayed, so it stays honest. Add `--allow-failure` when a
non-zero exit _is_ the evidence. Add `--redact '<regex>'` for tokens and keys — the
rendered demo names every pattern that was applied, so redaction never reads as
the real output.

### Attach evidence you did not produce on stdout

Screenshots, terminal recordings, downloaded payloads:

```console
<plugin-root>/scripts/demo-attach --demo <slug> \
  --title 'The rollup page after the import' \
  --look-for 'Maker and taker columns now sum to the total.' screenshot.png
```

### Render it

```console
<plugin-root>/scripts/demo-render.py .llm/demo/<slug> -o .llm/demo/<slug>/demo.html
```

Render into the demo directory, so the page and the evidence behind it travel together.
The renderer reads only the captured files, so the page cannot drift from what ran.
Use `--format md` when the demo is small enough to live in the conversation. Long
output is trimmed with a visible `… N lines omitted …` marker and a pointer to the
full file — never silently.

## Deliver it where the user is

`open` puts the demo on the screen of the machine running the command. The person
asking for it is often somewhere else — on a phone, on a tablet, driving the session
from another device. A demo delivered to an empty desk is not delivered.

Check, rather than assume:

```console
<plugin-root>/scripts/demo-presence
```

It reports idle seconds, whether the screen is locked, whether Tailscale is up, and
which tailnet peers are active, then exits `0` for present, `1` for away, `2` for
can't tell. Treat that output like any other captured evidence — it is a reading, not
a guess.

- **Present** — `open` the rendered page, and say the path
- **Away, or can't tell** — publish it and hand over a URL that works from their other device, and send the file itself so it reaches them even if the network does not
- **Never** end a demo with only a local `open` and a path on this machine

### Publish over Tailscale

```console
<plugin-root>/scripts/demo-publish .llm/demo/<slug>
```

This copies the whole demo — page plus every captured step — into the publish root and
prints the URL. Two environment settings drive it, so no host name or path is baked in:

- `DEMO_PUBLISH_DIR` — where published demos live. Defaults to `${XDG_DATA_HOME:-$HOME/.local/share}/demos`
- `DEMO_PUBLISH_URL` — the base URL that root is served at over the tailnet

Serve that root however the machine already serves things to the tailnet — a reverse
proxy behind `tailscale serve`, or `tailscale serve` pointed straight at the directory.
Prefer whatever the machine already does over standing up something new; reuse the
existing gateway and add one host to it.

When `DEMO_PUBLISH_URL` is unset the demo still publishes to disk and the script says
plainly that there is no URL, rather than printing one that will not resolve.

### Also hand over the file

Send the rendered page to the user directly as well as serving it. A URL needs them on
the tailnet; a delivered file does not. Both cost nothing, and between them the demo
arrives.

## Boundaries worth capturing

Reach for the command that shows the boundary itself, not a friendly summary of it.

- **HTTP** — `curl -sS -D- -X POST -H 'content-type: application/json' -d @request.json <url>`, so headers and status are in the capture. Pretty-print the body through `python3 -m json.tool` as its own step, and capture the request body too — both sides of the wire.
- **SQL** — the statement and its result, then the row: `sqlite3 app.db 'SELECT * FROM note ORDER BY id DESC LIMIT 3'`. Turn on statement logging where the system generates the SQL, and capture the generated statement rather than describing it.
- **Schema** — `sqlite3 app.db '.schema note'`, `psql -c '\d+ note'`, `SHOW CREATE TABLE note`. Show what the database stored, which is not always what the migration said.
- **On disk** — `ls -l`, `file`, `wc -c`, `xxd | head`, `tree -L 2`, `git status --porcelain`. For formats that are really archives or containers, show the container listing too.
- **CLI** — the exact invocation, including flags, and `--help` when the flags are the thing being demoed.
- **Web UI** — drive the real browser, screenshot it, and attach it. Pair the screenshot with the network request behind it so the picture is backed by the payload.
- **Library** — a short script that imports the published entry point and prints results, run for real. Not the test suite; a caller.
- **Background work** — the log lines the job wrote, `tail`ed from the real log file, plus the row or file it produced.

## Use real data

A demo built on data seeded for the demo proves the demo. Use records the system
actually holds, exports the user actually has, markets that are actually trading.

When only fixture data exists, say so in the step's own `--why`, out loud, before
the output — and prefer a real record over an invented one even when it is messier.
Never hand-seed a clean happy path and present it as evidence.

## Start from a known state

Prove the starting point before proving the change. An empty database shown empty,
a directory shown missing, a query returning zero rows — then the command, then the
same query again. Otherwise the reader cannot tell what the command did from what
was already there.

## Before and after is the proof

For a fix, capture the same command on both sides of it and let the difference speak.
Build the old binary in a worktree at the parent commit, or drive the flag that
disables the change, and run the identical input through each. Two screenshots, two
JSON dumps, two row sets. Assertion is not evidence; a diff is.

## Pace it one step at a time

One at a time is literal. Present one step, stop, and wait. Do not deliver a list of
ten things and ask for sign-off on all of them — every step earns its own follow-up
questions, and a wall of text gets skipped instead of read.

- Keep the remaining steps in internal todos so nothing is lost across the pauses
- Use AskUserQuestion at each pause, with real options
- Get sign-off on a step before moving to the next
- Demo before opening a pull request, and before calling anything done

## Annotate the output

The output is only evidence if the reader can read it.

- Map console columns to the fields they came from — this column is that JSON key
- Put headers on tables in the report; an unlabelled column is not proof of anything
- Define units, and say what a number is denominated in
- Explain any term the reader has not used themselves; jargon in a demo reads as evasion
- Name where the data lives — the file path, the table, the endpoint — so the reader can go look

## Offer choices when taste is the question

When the demo exists to settle how something looks or feels, build several real
variants and show them side by side rather than one and a description of the others.
Push each variant to its limit — the longest text, the fullest screen, the widest
table — because the interesting failure is at the edge.

## Say what it does not prove

Close with the honest caveats: what the demo covers, what it does not, which inputs
were pinned, which conditions were not exercised. A demo that overclaims costs more
trust than one that admits a gap.

## Keep proof that outlives the session

`.llm/demo/<slug>/` is the default and it is scratch. When the demo is the evidence
for a change — a pull request, a behaviour claim, a bug that must stay fixed — copy the
demo directory somewhere durable and committed, next to the code it vouches for, with
the pinned inputs and the command that reproduces it.
