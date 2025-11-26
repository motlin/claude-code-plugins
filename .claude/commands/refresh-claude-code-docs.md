---
description: Refresh the offline Claude Code documentation from code.claude.com
---

# Refresh Offline Claude Code Documentation

Update the offline documentation in `plugins/offline-claude-code-guide/docs/` with the latest from https://code.claude.com/docs/en/

## Steps

Run the refresh script:

```bash
plugins/offline-claude-code-guide/scripts/refresh-docs.sh
```

This script:

1. Downloads the docs map from code.claude.com
2. Parses and downloads all linked documentation files
3. Converts absolute links to relative links
4. Removes any invalid files (404 responses)
5. Reports the number of files downloaded

## Verification

After the script completes, verify the update was successful by checking the file count and reviewing any recent changes to the docs.
