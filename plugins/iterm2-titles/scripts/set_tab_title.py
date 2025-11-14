#!/usr/bin/env -S uv run --quiet --script
# /// script
# dependencies = ["iterm2"]
# ///

import asyncio
import iterm2
import sys
import os
from datetime import datetime

DEBUG_LOG = "/tmp/iterm2-titles-debug.log"
TAB_ID_FILE = "/tmp/iterm2-claude-tab-{termid}.txt"

def log(message):
    with open(DEBUG_LOG, 'a') as f:
        f.write(f"[{datetime.now().isoformat()}] set_title: {message}\n")

async def find_tab_by_id(app, tab_id):
    for window in app.terminal_windows:
        for tab in window.tabs:
            if tab.tab_id == tab_id:
                return tab
    return None

async def main(connection):
    app = await iterm2.async_get_app(connection)

    title = sys.argv[1] if len(sys.argv) > 1 else "Claude Code"
    iterm_session_id = os.environ.get('ITERM_SESSION_ID', '')
    termid = iterm_session_id.split(':')[0] if ':' in iterm_session_id else ''

    if not termid:
        log(f"No ITERM_SESSION_ID found, skipping update")
        return

    tab_id_file = TAB_ID_FILE.format(termid=termid)

    iterm_tab_id = None
    if os.path.exists(tab_id_file):
        with open(tab_id_file, 'r') as f:
            iterm_tab_id = f.read().strip()

    log(f"termid={termid}, file_tab_id={iterm_tab_id}, title={title}")

    if iterm_tab_id:
        target_tab = await find_tab_by_id(app, iterm_tab_id)
        if target_tab:
            log(f"Found tab with ID {iterm_tab_id}")
            await target_tab.async_set_title(title)
            log(f"Set title '{title}' on tab {target_tab.tab_id}")
        else:
            log(f"Could not find tab with ID {iterm_tab_id}, skipping update")
    else:
        log(f"No persisted tab ID found for termid={termid}, skipping update")

if __name__ == "__main__":
    try:
        iterm2.run_until_complete(main)
    except Exception as e:
        log(f"Error: {e}")
