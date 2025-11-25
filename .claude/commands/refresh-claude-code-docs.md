---
description: Refresh the offline Claude Code documentation from code.claude.com
---

# Refresh Offline Claude Code Documentation

Update the offline documentation in `plugins/offline-claude-code-guide/docs/` with the latest from https://code.claude.com/docs/en/

## Steps

### 1. Download the docs map

Download the fresh docs map file:

```bash
curl -s "https://code.claude.com/docs/en/claude_code_docs_map.md" -o plugins/offline-claude-code-guide/docs/claude_code_docs_map.md
```

### 2. Extract and download all linked docs

Parse the docs map to find all markdown file links matching the pattern `](https://code.claude.com/docs/en/*.md)` and download each one.

The links in the docs map look like:

```
### [overview](https://code.claude.com/docs/en/overview.md)
```

Download each linked `.md` file to `plugins/offline-claude-code-guide/docs/`. Skip any files that return 404 or empty content.

Example bash loop:

```bash
DOCS_DIR="plugins/offline-claude-code-guide/docs"
BASE_URL="https://code.claude.com/docs/en"

# Extract filenames from links like (https://code.claude.com/docs/en/filename.md)
grep -oE '\(https://code\.claude\.com/docs/en/[^)]+\.md\)' "$DOCS_DIR/claude_code_docs_map.md" | \
  sed 's/(https:\/\/code\.claude\.com\/docs\/en\///' | sed 's/)//' | \
  while read filename; do
    echo "Downloading $filename..."
    curl -s "$BASE_URL/$filename" -o "$DOCS_DIR/$filename"
  done
```

### 3. Replace absolute links with relative links

In `claude_code_docs_map.md`, replace all occurrences of `(https://code.claude.com/docs/en/` with `(./` to make the links relative.

### 4. Clean up invalid files

Check for any downloaded files that contain just `null` (404 response) and delete them. Also remove corresponding entries from the docs map if needed.

### 5. Verify the update

List the downloaded files and their sizes to confirm the update completed successfully.
