---
name: dev-server
description: Start or restart a project dev server on a specific or discovered port, wait until it is ready, and monitor it for automatic recovery. Use when the user asks to start, restart, keep alive, watch, or monitor a development server.
---

# Dev Server

Start the dev server for the current project and keep it running. Run everything in the current working directory; never hardcode or `cd` to a project path.

## Determine the port

Use the port the user names. Otherwise find the configured port in `vite.config.ts`, `app.config.ts`, `.env`, `package.json` scripts, `justfile`, or similar.

The user expects a consistent URL, so never switch ports. If the port is occupied, kill the occupant:

```bash
lsof -ti :<port> | xargs kill -9 2>/dev/null || true
```

## Start the server

Find the command in `justfile`, `package.json` scripts, `Makefile`, or equivalent (`just dev`, `pnpm dev`, `npm run dev`, `make dev`). Build prerequisites first when needed, such as a monorepo shared package.

Start it as a background process (the Bash tool's `run_in_background` in Claude Code), with `PORT=<port>` when the project honors it. Keep the process or session identifier so its output stays observable.

## Wait until ready

```bash
for i in $(seq 1 30); do curl -sf http://localhost:<port>/ >/dev/null 2>&1 && echo ready && break; sleep 1; done
```

Then tell the user the server is running at `http://localhost:<port>/`.

## Monitor and recover

Check the same URL about once a minute with the available recurring mechanism (`/loop 1m` where available) until the user asks to stop or the surrounding task ends. Stay quiet while it is healthy.

When a check fails:

- Inspect the retained process output for the cause.
- Kill any stale process on the port with the `lsof` command above.
- Rerun prerequisite builds if startup needs them.
- Restart the server as a new background process, wait for readiness, and tell the user it was restarted.

If restarts keep failing, report the relevant output and stop retrying.
