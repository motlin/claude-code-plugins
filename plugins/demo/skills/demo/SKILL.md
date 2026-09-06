---
name: demo
description: 'Demo working software by showing real data crossing real IO boundaries — the request on the wire, the SQL that ran, the row and the bytes on disk, the command and its captured output — recorded with Showboat, Rodney, VHS or screenshots rather than written by hand, then delivered where the user actually is. Use when asked to demo, to "show me it working", "I need to see it", "prove it", or to walk through what was built, and before opening a pull request or calling work done.'
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
- **Into storage** — the SQL that executed, the rows before and after, and the on-disk representation
- **Out to the human** — the page, the terminal, the report, the screenshot

Reading code aloud is not a demo. Neither is a table of what changed, a test-passed
count, or a paragraph beginning "the system now correctly". Those describe. A demo shows.

## Capture with Showboat, never author

Every byte of output in a demo comes from a tool that recorded it while the command
ran. Write the command; let the tool capture the result. Never retype output, tidy it,
reconstruct it from memory, or predict what it would say.

The rule: if it was typed, it is prose. If it is evidence, a capture tool produced it.

[Showboat](https://github.com/simonw/showboat) builds the document. It runs with no
install through `uvx showboat`, or `uv tool install showboat` to keep it around.

```console
uvx showboat init demo.md 'One POST, end to end'
uvx showboat note demo.md '## The table starts empty'
uvx showboat exec demo.md bash 'sqlite3 app.db "SELECT count(*) FROM note;"'
uvx showboat image demo.md screenshot.png
```

- `exec` appends the command and its captured output, prints that output, and exits with the command's own status — so a failure is visible immediately and still recorded
- `note` carries every word you write: the framing, what to look for, the caveats
- `image` copies a screenshot or recording into the document
- `pop` removes the most recent entry, for a step that went wrong in a way worth re-running rather than keeping

### Make it verifiable

`showboat verify demo.md` re-runs every code block and fails if any output has drifted.
That is the difference between a document that claims something and one that keeps
proving it, so aim for a demo that passes.

A demo only passes verification if it is idempotent. Reset state **inside** a captured
step rather than before the recording starts — a first block that empties the table is
part of the proof, while a reset you did off-camera makes the second run disagree with
the first. When a demo genuinely cannot be idempotent, run `verify` anyway and write
down in the document which blocks drift and why.

### Look at the rendered page before handing it over

Command output tells you the commands worked. It cannot tell you the document reads
correctly. Screenshot the rendered page once — with Rodney, or by opening it — and read
it as the recipient will. Defects that only appear there are common: a duplicated
section, a block in the wrong order, a fence that closed in the wrong place.

Two that bite in practice:

- **End captured output with a newline.** A command whose last byte is not a newline puts Showboat's closing fence on the same line as the output, and the stray ` ``` ` shows up in the page. Prefer `cat file` or add an `echo` rather than a bare `printf` without a trailing newline.
- **`pop` removes one entry, not one section.** A failed `exec` usually has a `note` in front of it; popping the exec leaves the note stranded, and re-adding both duplicates the heading. Pop the note too, or rebuild the document.

### Redaction stays visible

Never hand-edit a secret out of captured output. Put the redaction in the command
itself, where it is part of the evidence:

```console
uvx showboat exec demo.md bash 'curl -sS -D- "$URL" | sed -E "s/Bearer [A-Za-z0-9._-]+/Bearer «redacted»/"'
```

The reader can see exactly what was removed and that nothing else was.

## Pick the capture tool for what you are showing

| Showing                                                                 | Capture with                                                                                                      |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Shell, CLI, SQL, HTTP, file bytes, logs                                 | `showboat exec`                                                                                                   |
| A web page or web app                                                   | [Rodney](https://github.com/simonw/rodney) — `rodney start`, `open`, `wait`, `screenshot` — then `showboat image` |
| A terminal UI, an animation, anything where timing or keystrokes matter | a [VHS](https://github.com/charmbracelet/vhs) tape rendered to GIF, then `showboat image`                         |
| Charts from data                                                        | `chartroom`, then `showboat image`                                                                                |
| Anything only visible on a screen                                       | a screenshot, then `showboat image`                                                                               |

Rodney drives one persistent headless Chrome across many short commands, so a page can
be opened, waited on, asserted against and photographed as separate captured steps. Its
`exists`, `visible` and `assert` subcommands exit non-zero on failure, which makes them
evidence rather than narration. When Rodney is not installed, any browser-automation MCP
that produces a real screenshot file will do — what matters is that the image comes from
the running page, not from a description of it.

Reach for VHS when a still frame would lose the point: a progress display, a TUI, a
keystroke sequence, anything where the reader needs to see it move.

## Boundaries worth capturing

Reach for the command that shows the boundary itself, not a friendly summary of it.

- **HTTP** — `curl -sS -D- -X POST -H 'content-type: application/json' -d @request.json <url>`, so headers and status are in the capture. Capture the request body as its own step; both sides of the wire are the point.
- **SQL** — the statement and its result. Turn on statement logging where the system generates the SQL, and capture the generated statement rather than describing it.
- **Schema** — `.schema`, `\d+`, `SHOW CREATE TABLE`. Show what the database stored, which is not always what the migration said.
- **On disk** — show the **representation**, not the file's metadata. `sqlite3 db .dump`, `git cat-file -p`, `xxd` at the offset where the record actually sits, an archive listing. Size, mtime and page counts are trivia: they change nothing the reader understands, and a step that only reports them should be cut.
- **CLI** — the exact invocation including flags, and `--help` when the flags are the thing being demoed.
- **Web UI** — the screenshot, paired with the network request behind it, so the picture is backed by the payload.
- **Library** — a short script that imports the published entry point and prints results, run for real. Not the test suite; a caller.
- **Background work** — the log lines the job wrote, read from the real log file, plus the row or file it produced.

## Use real data

A demo built on data seeded for the demo proves the demo. Use records the system
actually holds, exports the user actually has.

When only fixture data exists, say so in a `note`, out loud, before the output — and
prefer a real record over an invented one even when it is messier. Never hand-seed a
clean happy path and present it as evidence.

## Start from a known state

Prove the starting point before proving the change. An empty table shown empty, a
directory shown missing, a query returning zero rows — then the command, then the same
query again. Otherwise the reader cannot tell what the command did from what was
already there.

## Before and after is the proof

For a fix, capture the same command on both sides of it and let the difference speak.
Build the old binary in a worktree at the parent commit, or drive the flag that disables
the change, and run the identical input through each. Two screenshots, two dumps, two
row sets. Assertion is not evidence; a diff is.

## Pace it one at a time

One at a time is literal. Present one step, stop, and wait. Do not deliver a list of ten
things and ask for sign-off on all of them — every step earns its own follow-up
questions, and a wall of text gets skipped instead of read.

- Keep the remaining steps in internal todos so nothing is lost across the pauses
- Use AskUserQuestion at each pause, with real options
- Get sign-off on a step before moving to the next
- Demo before opening a pull request, and before calling anything done

## Annotate the output

The output is only evidence if the reader can read it.

- Map console columns to the fields they came from — this column is that JSON key
- Put headers on tables; an unlabelled column is not proof of anything
- Define units, and say what a number is denominated in
- Explain any term the reader has not used themselves; jargon in a demo reads as evasion
- Name where the data lives — the file path, the table, the endpoint — so the reader can go look

## Offer choices when taste is the question

When the demo exists to settle how something looks or feels, build several real variants
and show them side by side rather than one and a description of the others. Push each
variant to its limit — the longest text, the fullest screen, the widest table — because
the interesting failure is at the edge.

## Say what it does not prove

Close with the honest caveats: what the demo covers, what it does not, which inputs were
pinned, which conditions were not exercised, which blocks fail `verify` and why. A demo
that overclaims costs more trust than one that admits a gap.

## Deliver it where the user is

`open` puts the demo on the screen of the machine running the command. The person asking
for it is often somewhere else — on a phone, on a tablet, driving the session from
another device. A demo delivered to an empty desk is not delivered.

Check, rather than assume:

```console
<plugin-root>/scripts/demo-presence
```

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/demo/SKILL.md` file.

It reports idle seconds, whether the screen is locked, whether Tailscale is up and which
tailnet peers are active, then exits `0` present, `1` away, `2` can't tell. Treat that
output like any other captured evidence — a reading, not a guess.

Render the document to a page first, since Showboat writes markdown:

```console
<plugin-root>/scripts/demo-render.py demo.md -o demo.html
```

Then deliver by whichever of these the environment offers, best first:

- **A Claude Artifact**, when the Artifact tool is available. It reaches any device with no VPN and no network of the user's involved. Render with `--fragment`, since the artifact host supplies its own document skeleton.
- **A URL on the tailnet**, with `<plugin-root>/scripts/demo-publish demo-dir/`. It copies the document, its images and the rendered page into the publish root and prints the URL. `DEMO_PUBLISH_DIR` sets where published demos live (default `${XDG_DATA_HOME:-$HOME/.local/share}/demos`) and `DEMO_PUBLISH_URL` the base URL that root is served at. Serve that root however the machine already serves things to the tailnet, and reuse the existing gateway rather than standing up something new. With `DEMO_PUBLISH_URL` unset it still publishes and says plainly that there is no URL.
- **The file itself**, sent to the user directly. A URL needs them on the tailnet; a delivered file does not.
- **`open`**, but only when the presence check says they are here.

Never end a demo with only a local `open` and a path on this machine.

## Keep proof that outlives the session

A demo directory under `.llm/` is scratch. When the demo is the evidence for a change —
a pull request, a behaviour claim, a bug that must stay fixed — copy the document and its
images somewhere durable and committed, next to the code it vouches for, so
`showboat verify` can be run against it again later.
