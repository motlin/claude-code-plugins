# demo

`/demo:demo [target]` captures real IO — requests, SQL, rows, files, command output — with Showboat, Rodney, VHS, or `chartroom`, and delivers it where the user is.

Scripts: `demo-render.py` (Showboat markdown to self-contained HTML), `demo-presence` (is the user at this machine), `demo-publish` (copy a demo to the publish root and print its URL).

## Setup

To publish over a tailnet, serve a directory (for example with `tailscale serve`) and set:

- `DEMO_PUBLISH_DIR` — publish root, default `${XDG_DATA_HOME:-$HOME/.local/share}/demos`
- `DEMO_PUBLISH_URL` — the base URL that root is served at

Requires `python3`, `uv`, and `rsync`; optionally `rodney`, `vhs`, and `chartroom`.
