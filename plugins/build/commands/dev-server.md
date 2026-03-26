---
description: Start the dev server and keep it running
argument-hint: "[port]"
---

Start the wip dev server and keep it running.

## Arguments

Port number: $ARGUMENTS

If `$ARGUMENTS` is empty or not a number, determine the port by checking the project's config files (e.g., `vite.config.ts`, `app.config.ts`, `.env`, `package.json` scripts) for a configured dev server port.

## Instructions

1. **Kill anything on the port**

   Check if the port is already in use. If so, kill the process occupying it:

   ```bash
   lsof -ti :<port> | xargs kill -9 2>/dev/null || true
   ```

2. **Build shared package first**

   The web package depends on `@wip/shared`. Build it before starting the dev server:

   ```bash
   pnpm --filter @wip/shared build
   ```

3. **Start the dev server in the background**

   ```bash
   cd /Users/craig/projects/wip && PORT=<port> just dev
   ```

   Run this in the background using `run_in_background`.

4. **Wait for the server to be ready**

   Poll until the server responds:

   ```bash
   for i in $(seq 1 30); do curl -sf http://localhost:<port>/ > /dev/null 2>&1 && echo "ready" && break; sleep 1; done
   ```

5. **Report the URL**

   Tell the user the dev server is running at `http://localhost:<port>/`.

6. **Start a watchdog loop**

   Use `/loop 1m` to run a recurring check every 1 minute. The check should:
   - Verify the server is responding: `curl -sf http://localhost:<port>/ > /dev/null 2>&1`
   - If it's not responding:
     1. Kill anything on the port: `lsof -ti :<port> | xargs kill -9 2>/dev/null || true`
     2. Rebuild shared: `pnpm --filter @wip/shared build`
     3. Restart: `PORT=<port> just dev` (in background)
     4. Notify the user that the server was restarted
