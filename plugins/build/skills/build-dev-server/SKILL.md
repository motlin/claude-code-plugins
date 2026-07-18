---
name: build-dev-server
description: Start or restart a project dev server on a specific or discovered port, wait until it is ready, and monitor it for automatic recovery. Use when the user asks to start, restart, keep alive, watch, or monitor a development server.
---

# Build Dev Server

Start the dev server for the current project and keep it running. Run commands in the current working directory.

## Determine Port

If the user provided a port, use it. Otherwise inspect project config such as `vite.config.ts`, `app.config.ts`, `.env`, `package.json`, `justfile`, or similar.

Always use the determined port. If occupied, kill the existing process instead of switching ports:

```bash
lsof -ti :<port> | xargs kill -9 2>/dev/null || true
```

## Start Server

Discover the command from `justfile`, `package.json`, `Makefile`, or equivalent. Common commands:

- `just dev`
- `pnpm dev`
- `npm run dev`
- `make dev`

Run prerequisite builds first if the project needs them.

Start the server in a persistent background process or terminal session with `PORT=<port>` when the project honors that variable. Retain the process or session identifier so its output and state remain observable after startup.

## Wait Until Ready

Poll:

```bash
for i in $(seq 1 30); do curl -sf http://localhost:<port>/ >/dev/null 2>&1 && echo ready && break; sleep 1; done
```

Report `http://localhost:<port>/`.

## Monitor and Recover

After the server is ready, use the available recurring-monitoring or wait mechanism to check the same URL about once per minute. Keep monitoring until the user asks to stop or the surrounding task ends.

For each check:

- Confirm the server responds successfully on the determined port.
- If healthy, continue monitoring without sending repetitive status messages.
- If unhealthy, inspect the retained process output for the cause.
- Kill any stale process still occupying the port.
- Repeat prerequisite builds when they are required for startup.
- Restart the server in a new persistent process or session.
- Wait for readiness again and notify the user that recovery occurred.

Do not silently switch ports during recovery. If restart repeatedly fails, report the relevant output and stop retrying blindly.
