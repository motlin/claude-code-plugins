---
name: dev-server
description: Start or restart a project dev server on a specific or discovered port, wait until it is ready, and monitor it for automatic recovery. Use when the user asks to start, restart, keep alive, watch, or monitor a development server.
---

# Dev Server

Start the dev server for the current project and keep it running. All commands run in the current working directory; never hardcode or `cd` to a specific project path.

## Determine Port

If the user names a port, use it. Otherwise inspect project config such as `vite.config.ts`, `app.config.ts`, `.env`, `package.json` scripts, `justfile`, or similar for a configured dev server port.

Always use the determined port. If it is occupied, kill the existing process instead of switching ports; the user expects the server at a consistent URL:

```bash
lsof -ti :<port> | xargs kill -9 2>/dev/null || true
```

## Start Server

Discover the command from `justfile`, `package.json` scripts, `Makefile`, or equivalent. Common commands:

- `just dev`
- `pnpm dev`
- `npm run dev`
- `make dev`

If the project has dependencies that need building first (for example a monorepo shared package), identify and run those build steps before starting the server.

Start the server as a background process (for example, the Bash tool's `run_in_background` in Claude Code) with `PORT=<port>` when the project honors that variable. Retain the process or session identifier so its output and state remain observable after startup.

## Wait Until Ready

Poll:

```bash
for i in $(seq 1 30); do curl -sf http://localhost:<port>/ >/dev/null 2>&1 && echo ready && break; sleep 1; done
```

Tell the user the dev server is running at `http://localhost:<port>/`.

## Monitor and Recover

After the server is ready, use the available recurring-monitoring or wait mechanism to check the same URL about once per minute (`/loop 1m` where available). Keep monitoring until the user asks to stop or the surrounding task ends.

For each check:

- Confirm the server responds: `curl -sf http://localhost:<port>/ >/dev/null 2>&1`
- If healthy, continue monitoring without sending repetitive status messages.
- If unhealthy, inspect the retained process output for the cause.
- Kill any stale process still occupying the port: `lsof -ti :<port> | xargs kill -9 2>/dev/null || true`
- Repeat prerequisite builds when they are required for startup.
- Restart the server as a new background process.
- Wait for readiness again and notify the user that the server was restarted.

Do not silently switch ports during recovery. If restart repeatedly fails, report the relevant output and stop retrying blindly.
