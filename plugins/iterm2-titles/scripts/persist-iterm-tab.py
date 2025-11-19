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

    iterm_session_id = os.environ.get('ITERM_SESSION_ID', '')
    if not iterm_session_id or ':' not in iterm_session_id:
        log(f"Invalid ITERM_SESSION_ID: {iterm_session_id}")
        return

    termid = iterm_session_id.split(':')[0]
    session_uuid = iterm_session_id.split(':')[1]

    session = app.get_session_by_id(session_uuid)
    tab = session.tab if session else None

    if tab is not None:
        tab_id_file = TAB_ID_FILE.format(termid=termid)
        log(f"tab_id={tab.tab_id}, termid={termid}, session_uuid={session_uuid}")

        with open(tab_id_file, 'w') as f:
            f.write(tab.tab_id)

        log(f"Persisted tab_id={tab.tab_id} to {tab_id_file}")
    else:
        log(f"Could not find tab for session {session_uuid}")

if __name__ == "__main__":
    try:
        iterm2.run_until_complete(main)
    except Exception as e:
        log(f"Error: {e}")
