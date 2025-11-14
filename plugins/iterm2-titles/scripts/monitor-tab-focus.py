#!/usr/bin/env -S uv run --quiet --script
# /// script
# dependencies = ["iterm2"]
# ///

import asyncio
import iterm2
import os
import re
from datetime import datetime

DEBUG_LOG = "/tmp/iterm2-titles-debug.log"
TAB_ID_FILE = "/tmp/iterm2-claude-tab-{termid}.txt"

def log(message):
    with open(DEBUG_LOG, 'a') as f:
        f.write(f"[{datetime.now().isoformat()}] monitor: {message}\n")

def strip_leading_icon(title):
    """Remove leading icon and space from title, leaving just the directory name."""
    # Pattern matches: optional icon (emoji/symbol) + space + rest
    # This handles icons like ✓, ✻, ○, ?, ⌫, $, ✎, …
    pattern = r'^[^\w\s/]+\s+'
    stripped = re.sub(pattern, '', title)
    return stripped

async def monitor_tab_focus(connection, tab_id):
    """Monitor for when the specified tab is focused and strip leading icons."""
    app = await iterm2.async_get_app(connection)

    log(f"Starting monitor for tab_id={tab_id}")

    async def on_tab_selected(tab):
        if tab.tab_id == tab_id:
            current_title = await tab.async_get_variable("titleOverride")
            log(f"Tab focused: current_title='{current_title}'")

            # Strip leading icon if present
            new_title = strip_leading_icon(current_title)

            if new_title != current_title:
                await tab.async_set_title(new_title)
                log(f"Stripped icon: new_title='{new_title}'")
            else:
                log(f"No icon to strip")

    # Monitor all tab selection events
    async with iterm2.FocusMonitor(connection) as monitor:
        while True:
            update = await monitor.async_get_next_update()
            if update.selected_tab_changed:
                tab = app.get_tab_by_id(update.selected_tab_changed.tab_id)
                if tab:
                    await on_tab_selected(tab)

async def main(connection):
    iterm_session_id = os.environ.get('ITERM_SESSION_ID', '')
    termid = iterm_session_id.split(':')[0] if ':' in iterm_session_id else ''

    if not termid:
        log("No ITERM_SESSION_ID found, exiting")
        return

    tab_id_file = TAB_ID_FILE.format(termid=termid)

    # Wait for tab ID to be persisted
    for _ in range(10):
        if os.path.exists(tab_id_file):
            break
        await asyncio.sleep(0.1)
    else:
        log(f"Tab ID file not found: {tab_id_file}")
        return

    with open(tab_id_file, 'r') as f:
        tab_id = f.read().strip()

    log(f"Monitoring tab_id={tab_id} for focus events")

    try:
        await monitor_tab_focus(connection, tab_id)
    except asyncio.CancelledError:
        log("Monitor cancelled")
    except Exception as e:
        log(f"Monitor error: {e}")

if __name__ == "__main__":
    try:
        iterm2.run_forever(main)
    except Exception as e:
        log(f"Fatal error: {e}")
