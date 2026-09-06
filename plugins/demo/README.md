# demo

Demo working software by showing real data crossing real IO boundaries — the request on the wire, the SQL that ran, the row and the bytes on disk, the command and its output — recorded by a capture tool rather than written by hand, then delivered where the user actually is.

Capture is [Showboat](https://github.com/simonw/showboat), with [Rodney](https://github.com/simonw/rodney), [VHS](https://github.com/charmbracelet/vhs) and `chartroom` for the things a shell command cannot show. This plugin adds the parts those tools leave to you: choosing what to capture, pacing the walkthrough, and getting the finished demo onto the right screen.

## Commands

### `/demo`

Plan the IO trace, capture each step with the right tool, deliver the steps one at a time, and hand over the finished demo.

## Skills

### `demo`

Triggers on "demo this", "show me it working", "I need to see it", "prove it", and before opening a pull request. Covers what counts as a demo, which capture tool fits what you are showing, keeping the document verifiable, using real data, before-and-after evidence, pacing, annotating output, and stating what the demo does not prove.

## Scripts

### `demo-render.py`

Renders a Showboat markdown document as one self-contained HTML page, inlining every referenced image so the page survives being copied anywhere.

```console
scripts/demo-render.py demo.md -o demo.html
scripts/demo-render.py demo.md --fragment -o fragment.html
```

`--fragment` emits head contents and body markup only, for hosts that supply their own document skeleton — Claude Artifacts among them.

### `demo-presence`

Reports whether the user is at this machine — idle seconds, screen lock, Tailscale state, active tailnet peers — and exits `0` present, `1` away, `2` unknown. Stops a demo being `open`ed on a screen nobody is looking at.

Set `DEMO_IDLE_SECONDS` or `DEMO_SCREEN_LOCKED` to supply a reading instead of probing for it, on hosts where the probes do not work; the literal `unknown` states that there is no reading. `DEMO_IDLE_THRESHOLD` sets the idle cutoff in seconds (default 300).

```console
$ scripts/demo-presence
idle_seconds=10569
screen_locked=true
tailscale_up=true
active_remote_peers=ipad
verdict=away
```

### `demo-publish`

Copies a demo — the document, its images and the rendered page — into the publish root and prints the URL to hand over, so it opens on a phone rather than on this desk.

```console
scripts/demo-publish .llm/demo/import-pipeline
```

- `DEMO_PUBLISH_DIR` — where published demos live. Default: `${XDG_DATA_HOME:-$HOME/.local/share}/demos`
- `DEMO_PUBLISH_URL` — the base URL that root is served at over the tailnet

Serve the publish root however the machine already exposes things to the tailnet: a reverse proxy behind `tailscale serve`, or `tailscale serve` pointed at the directory. With `DEMO_PUBLISH_URL` unset, the demo still publishes and the script says there is no URL instead of printing one that will not resolve.

## Requirements

- `python3`, and `uv` (Showboat and the markdown renderer run through `uvx` with no install)
- `rsync`, for `demo-publish`
- Optional, depending on what is being captured: `rodney` for browser screenshots, `vhs` for terminal recordings, `chartroom` for charts
