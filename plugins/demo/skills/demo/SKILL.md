---
name: demo
description: 'Demo working software by showing real data crossing real IO boundaries — the request on the wire, the SQL that ran, the row and the bytes on disk, the command and its captured output — recorded with Showboat, Rodney, VHS or screenshots rather than written by hand, then delivered where the user actually is. Use when asked to demo, to "show me it working", "I need to see it", "prove it", or to walk through what was built, and before opening a pull request or calling work done.'
---

# Demo

A demo shows data, not code or a summary of code: a real request, a real row, a real file, a real command and what it printed. Demo what the user named; with no target, demo the work done so far in this session.

Before designing an interactive demo, read [Red Blob Games' Making of: Circle drawing tutorial](https://www.redblobgames.com/making-of/circle-drawing/) as the quality benchmark for teaching through interaction.

## What counts as a demo

Show the data crossing the system's boundaries, in the order it crosses them:

- **In at the edge** — the HTTP request and response on the wire, the CLI invocation, the input file, the message off the queue
- **Through the work** — the command that does the thing, run for real
- **Into storage** — the SQL that executed, the rows before and after, the on-disk representation
- **Out to the human** — the page, the terminal, the report, the screenshot

Reading code aloud, a table of what changed, a test-passed count, or "the system now correctly…" is not a demo.

## Capture with Showboat, never author

Every byte of output comes from a tool that recorded it while the command ran. Never retype, tidy, reconstruct, or predict output. If it was typed, it is prose; evidence comes from a capture tool.

[Showboat](https://github.com/simonw/showboat) builds the document, via `uvx showboat` (or `uv tool install showboat`):

```console
uvx showboat init demo.md 'One POST, end to end'
uvx showboat note demo.md '## The table starts empty'
uvx showboat exec demo.md bash 'sqlite3 app.db "SELECT count(*) FROM note;"'
uvx showboat image demo.md screenshot.png
```

- `exec` appends the command and its captured output, prints it, and exits with the command's status
- `note` carries all prose: framing, what to look for, caveats
- `image` copies a screenshot or recording into the document
- `pop` removes the most recent entry

### Make it verifiable

`showboat verify demo.md` re-runs every block and fails if output drifted. Aim for a demo that passes, which requires idempotence: reset state inside a captured step (a first block that empties the table), not off-camera before recording. When a demo cannot be idempotent, run `verify` anyway and note in the document which blocks drift and why.

### Look at the rendered page before handing it over

Screenshot the rendered page once (Rodney, or open it) and read it as the recipient will. Look for duplicated sections, misordered blocks, and broken fences. Two known traps:

- **End captured output with a newline.** Otherwise Showboat's closing fence lands on the output line and a stray ` ``` ` shows in the page. Prefer `cat file` or add an `echo` over a bare `printf`.
- **`pop` removes one entry, not one section.** A failed `exec` usually follows a `note`; pop both or rebuild, or the heading gets duplicated.

### Redaction stays visible

Never hand-edit a secret out of captured output. Redact inside the command so the redaction is part of the evidence:

```console
uvx showboat exec demo.md bash 'curl -sS -D- "$URL" | sed -E "s/Bearer [A-Za-z0-9._-]+/Bearer «redacted»/"'
```

## Pick the capture tool for what you are showing

| Showing                                                                 | Capture with                                                                                                      |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Shell, CLI, SQL, HTTP, file bytes, logs                                 | `showboat exec`                                                                                                   |
| A web page or web app                                                   | [Rodney](https://github.com/simonw/rodney) — `rodney start`, `open`, `wait`, `screenshot` — then `showboat image` |
| A terminal UI, an animation, anything where timing or keystrokes matter | a [VHS](https://github.com/charmbracelet/vhs) tape rendered to GIF, then `showboat image`                         |
| Charts from data                                                        | `chartroom`, then `showboat image`                                                                                |
| Anything only visible on a screen                                       | a screenshot, then `showboat image`                                                                               |

Rodney drives one persistent headless Chrome across short commands, so opening, waiting, asserting, and photographing are separate captured steps. Its `exists`, `visible` and `assert` subcommands exit non-zero on failure, which makes them evidence. Without Rodney, any browser-automation MCP that writes a real screenshot file works.

## Boundaries worth capturing

Capture the boundary itself, not a friendly summary of it.

- **HTTP** — `curl -sS -D- -X POST -H 'content-type: application/json' -d @request.json <url>`, so headers and status are captured. Capture the request body as its own step.
- **SQL** — the statement and its result. Where the system generates SQL, turn on statement logging and capture the generated statement.
- **Schema** — `.schema`, `\d+`, `SHOW CREATE TABLE`: what the database stored, not what the migration said.
- **On disk** — the representation, not metadata: `sqlite3 db .dump`, `git cat-file -p`, `xxd` at the record's offset, an archive listing. Cut steps that only report size, mtime, or page counts.
- **CLI** — the exact invocation with flags, and `--help` when the flags are the point.
- **Web UI** — the screenshot plus the network request behind it.
- **Library** — a short script that imports the published entry point and prints results. A caller, not the test suite.
- **Background work** — the log lines from the real log file, plus the row or file it produced.

## Use real data

Use records the system actually holds and exports the user actually has. When only fixture data exists, say so in a `note` before the output. Never hand-seed a clean happy path and present it as evidence.

## Start from a known state, then show before and after

Prove the starting point first: the empty table, the missing directory, the zero-row query. Then the command, then the same query again.

For a fix, run the identical input on both sides of it: build the old binary in a worktree at the parent commit, or drive the flag that disables the change. Two screenshots, two dumps, two row sets.

## Pace it one at a time

Present one step, stop, and wait. Never deliver a list of steps for sign-off in one go.

- Track the remaining steps in internal todos across pauses.
- At each pause, ask whether to continue to the named next step, following the session's question-routing rules with a question tool callable in the current mode (`AskUserQuestion` in Claude Code, a suitable Codex question tool; `request_user_input` only when the mode permits it). Offer continue, revisit, or stop when the tool supports options.
- If no question tool is callable or the call fails, ask in plain text and end the turn.
- Continue only on explicit sign-off. Silence, a timeout, or an empty tool response is not approval. After addressing a question or change request, ask again.

## Annotate the output

- Map console columns to the fields they came from
- Put headers on tables
- Define units and denominations
- Explain terms the reader has not used themselves
- Name where the data lives — file path, table, endpoint

## Offer choices when taste is the question

When the demo settles how something looks or feels, build several real variants side by side, and push each to its limit (longest text, fullest screen, widest table).

## Say what it does not prove

Close with caveats: what the demo covers and does not, which inputs were pinned, which conditions were not exercised, which blocks fail `verify` and why.

## Deliver it where the user is

The user is often on another device, so a local `open` may land on an empty desk. Resolve `<plugin-root>` before running plugin scripts: `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, the plugin root containing this `skills/demo/SKILL.md`.

Check presence rather than assuming:

```console
<plugin-root>/scripts/demo-presence
```

It reports idle seconds, screen lock, Tailscale state, and active tailnet peers, then exits `0` present, `1` away, `2` can't tell.

Render the document to a page:

```console
<plugin-root>/scripts/demo-render.py demo.md -o demo.html
```

Deliver by the best option the environment offers, and send the file as well whichever you use:

- **A Claude Artifact**, when the Artifact tool is available. It reaches any device with no VPN. Render with `--fragment`, since the artifact host supplies the document skeleton.
- **A tailnet URL**, otherwise, via `<plugin-root>/scripts/demo-publish demo-dir/`, which copies the document, images, and rendered page into the publish root and prints the URL. `DEMO_PUBLISH_DIR` sets the root (default `${XDG_DATA_HOME:-$HOME/.local/share}/demos`) and `DEMO_PUBLISH_URL` its base URL. Reuse the machine's existing tailnet gateway rather than standing up a new server. With `DEMO_PUBLISH_URL` unset it still publishes and says there is no URL.
- **The file itself**, sent directly. It does not need the tailnet.
- **`open`**, only when the presence check says the user is here.

Never end a demo with only a local `open` and a path on this machine.

## Finish with verification

Run `uvx showboat verify demo.md` and report the result, including which blocks drift and why.

## Keep proof that outlives the session

A demo under `.llm/` is scratch. When the demo is evidence for a change (a pull request, a behavior claim, a regression that must stay fixed), copy the document and images somewhere committed next to the code, so `showboat verify` can run again later.
