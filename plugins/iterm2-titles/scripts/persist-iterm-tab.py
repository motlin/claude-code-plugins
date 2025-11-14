#!/usr/bin/env -S uv run --quiet --script
# /// script
# dependencies = ["iterm2"]
# ///

import asyncio
import iterm2
import os
import sys
from datetime import datetime

DEBUG_LOG = "/tmp/iterm2-titles-debug.log"
TAB_ID_FILE = "/tmp/iterm2-claude-tab-{termid}.txt"

def log(message):
    with open(DEBUG_LOG, 'a') as f:
        f.write(f"[{datetime.now().isoformat()}] persist: {message}\n")

async def main(connection):
    app = await iterm2.async_get_app(connection)
    window = app.current_terminal_window
    if window is not None:
        tab = window.current_tab
        if tab is not None:
            iterm_session_id = os.environ.get('ITERM_SESSION_ID', '')
            termid = iterm_session_id.split(':')[0] if ':' in iterm_session_id else ''

            if termid:
                tab_id_file = TAB_ID_FILE.format(termid=termid)
                log(f"tab_id={tab.tab_id}, termid={termid}")

                with open(tab_id_file, 'w') as f:
                    f.write(tab.tab_id)

                log(f"Persisted tab_id={tab.tab_id} to {tab_id_file}")
            else:
                log(f"No ITERM_SESSION_ID found")

if __name__ == "__main__":
    try:
        iterm2.run_until_complete(main)
    except Exception as e:
        log(f"Error: {e}")
