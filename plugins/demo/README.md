# demo

Demo working software by showing real data crossing real IO boundaries — the request on the wire, the SQL that ran, the rows and DDL on disk, the command and its output — with every byte recorded by a capture script rather than written by hand.

## Commands

### `/demo`

Demo the work: plan the IO trace, capture each step, deliver them one at a time, and render the result as a page.

## Skills

### `demo`

Triggers on "demo this", "show me it working", "I need to see it", "prove it", and before opening a pull request. Covers what counts as a demo, which boundaries to capture, using real data, before-and-after evidence, pacing, annotating output, and stating what the demo does not prove.

## Scripts

### `demo-capture`

Runs a command and records the real stdout, stderr, and exit code into a step directory. Output is written by the script as the command runs, so the rendered demo cannot drift from what happened.

```console
scripts/demo-capture --demo import-pipeline \
  --title 'Import one real export' \
  --why 'This is the only way data enters the system.' \
  --look-for 'Four transactions in, two paired into one move.' \
  -- ./bin/run.js import ~/Downloads/export.csv
```

Use `--sh '<string>'` for pipelines, `--allow-failure` when a non-zero exit is the evidence, and `--redact '<ere>'` to mask secrets (every applied pattern is named in the rendered demo).

### `demo-attach`

Records an existing file — screenshot, recording, payload dump — as a step, copying it into the demo so later edits to the original cannot change what the demo shows.

```console
scripts/demo-attach --demo import-pipeline --title 'The page after the import' shot.png
```

### `demo-render.py`

Builds a self-contained HTML page (or markdown with `--format md`) from the captured steps. Images embed as data URIs; long output is trimmed with a visible `… N lines omitted …` marker and a pointer to the full file.

```console
scripts/demo-render.py .llm/demo/import-pipeline -o .llm/demo/import-pipeline/demo.html
```

### `demo-presence`

Reports whether the user is at this machine — idle seconds, screen lock, Tailscale state, active tailnet peers — and exits `0` present, `1` away, `2` unknown. Prevents a demo from being `open`ed on a screen nobody is looking at.

```console
$ scripts/demo-presence
idle_seconds=10569
screen_locked=true
tailscale_up=true
active_remote_peers=ipad
verdict=away
```

### `demo-publish`

Copies a rendered demo — page plus every captured step — into the publish root and prints the URL to hand over, so it opens on a phone or tablet rather than on this desk.

```console
scripts/demo-publish .llm/demo/import-pipeline
```

- `DEMO_PUBLISH_DIR` — where published demos live. Default: `${XDG_DATA_HOME:-$HOME/.local/share}/demos`
- `DEMO_PUBLISH_URL` — the base URL that root is served at over the tailnet

Serve the publish root however the machine already exposes things to the tailnet: a reverse proxy behind `tailscale serve`, or `tailscale serve` pointed at the directory. With `DEMO_PUBLISH_URL` unset, the demo still publishes and the script says there is no URL instead of printing one that will not resolve.

## Layout

Demos live under `.llm/demo/<slug>/` by default; set `DEMO_ROOT` to change it and `DEMO_SLUG` to avoid repeating `--demo`. Each step is a directory of plain files (`command`, `stdout`, `stderr`, `exit`, `title`, `why`, `look_for`), so a demo stays readable and greppable without the renderer.

## Requirements

- `bash`, `python3`, and `rsync` (for `demo-publish`)
