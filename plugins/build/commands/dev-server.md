---
description: Start the dev server and keep it running
argument-hint: '[port]'
---

Start the dev server for the current project and keep it running.

All commands run in the current working directory — never hardcode or `cd` to a specific project path.

## Arguments

Port number: $ARGUMENTS

If `$ARGUMENTS` is empty or not a number, determine the port by checking the project's config files (e.g., `vite.config.ts`, `app.config.ts`, `.env`, `package.json` scripts) for a configured dev server port.

**Important:** Always use the determined port. If the port is occupied, kill the existing process — never switch to a different port. The user expects the server at a consistent URL.

## Instructions

### Discover how to start the dev server

Look at the project's `justfile`, `package.json` scripts, `Makefile`, or similar to find the dev server command. Common patterns:

- `just dev`
- `pnpm dev` / `npm run dev`
- `make dev`

If the project has dependencies that need building first (e.g., a monorepo shared package), identify and run those build steps before starting the server.

### Kill anything on the port

Check if the port is already in use. If so, kill the process occupying it:

```bash
lsof -ti :<port> | xargs kill -9 2>/dev/null || true
```

### Run any prerequisite builds

If the project requires building shared/dependency packages first, do so now.

### Start the dev server in the background

Run the discovered dev command with `PORT=<port>` (if the project uses a PORT env var), using `run_in_background`.

### Wait for the server to be ready

Poll until the server responds:

```bash
for i in $(seq 1 30); do curl -sf http://localhost:<port>/ > /dev/null 2>&1 && echo "ready" && break; sleep 1; done
```

### Report the URL

Tell the user the dev server is running at `http://localhost:<port>/`.

### Start a watchdog loop

Use `/loop 1m` to run a recurring check every 1 minute. The check should:

- Verify the server is responding: `curl -sf http://localhost:<port>/ > /dev/null 2>&1`
- If it's not responding:
    - Kill anything on the port: `lsof -ti :<port> | xargs kill -9 2>/dev/null || true`
    - Re-run prerequisite builds if applicable
    - Restart the dev server (in background)
    - Notify the user that the server was restarted
